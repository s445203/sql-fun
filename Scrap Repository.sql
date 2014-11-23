--Display the detailed orders report 
SELECT G.Code AS Grupa,G.Ime AS 'Dostavchik',K.Kod1 AS 'SMC',K.Ime1 AS 'SMC Ime',Orders.ChistaZaiavka AS 'Nuzhna Poruchka'
FROM T2012.dbo.sgQualityScores QS 
LEFT JOIN T2012.dbo.sgOrderNeed Orders ON QS.SMCId = Orders.SMCId
LEFT JOIN T2014.dbo.Klas_SMC K ON K.ID = QS.SMCID
LEFT JOIN T2014.dbo.Grupi_SMC G ON G.Code = K.Grupi
WHERE Orders.SMCId IS NOT NULL AND Orders.ChistaZaiavka > 0
ORDER BY K.Kod1

--Syntax for recreating the order need table
DROP TABLE T2012.dbo.sgOrderNeed;
CREATE TABLE T2012.dbo.sgOrderNeed
(
    SMCId INT NULL,
	OrderQ Real NULL,
	ChistaZaiavka Real NULL,
	OrderQs9 Real NULL,
  Stock Real NULL,
	DnevnaZagubaOtZakusnenieBGN Real NULL,
    DnevnaZagubaOtDupkaBGN Real NULL
);
CREATE UNIQUE INDEX sgIxOrderNeed ON T2012.dbo.sgOrderNeed(SMCId);
--Syntax for recreating the persistent quality scores data
DROP TABLE T2012.dbo.sgQualityScores;
CREATE TABLE T2012.dbo.sgQualityScores
(
	SMCId INT NULL,
	COGS Real NULL,
	Revenue Real NULL,
	GP Real NULL,
	Kol Real NULL,
	GPRank Int NULL,
	KolRank Int NULL,
	Quality Real NULL,
	MaxFaktKol Real NULL,
	SofiaKol Real NULL,
	VarnaKol Real NULL,
	ByalaKol Real NULL,
	RuseKol  Real NULL,
	VTKol Real NULL
);
CREATE UNIQUE INDEX sgIxQualityScores ON T2012.dbo.sgQualityScores(SMCId);
--Weekly reporting. Flip > to < to get izlishuk. 
SELECT AVG(QS.Quality) AS 'Sredno Kachestvo na SMC s Nuzhda za poruchvane',
	   SUM(ROUND(Orders.OrderQ,0) * K.CenaO1) AS 'Stoinost na cialata poruchka', COUNT(*) AS 'Broi SMCta za poruchvane',SUM(Orders.DnevnaZagubaOtZakusnenieBGN) AS DnevnaZagubaOtZakusnenieBGN
FROM T2012.dbo.sgQualityScores QS 
LEFT JOIN T2012.dbo.sgOrderNeed Orders ON QS.SMCId = Orders.SMCId
LEFT JOIN T2014.dbo.Klas_SMC K ON K.ID = QS.SMCID
LEFT JOIN T2014.dbo.Grupi_SMC G ON G.Code = K.Grupi
WHERE Orders.SMCId IS NOT NULL AND ROUND(Orders.OrderQ,0) > 0
ORDER BY DnevnaZagubaOtZakusnenieBGN DESC;

--Number of 9s
SELECT COUNT(*) FROM T2012.dbo.sgOrderNeed WHERE OrderQs9 = 999999
--2 year dead stock lookup that's not right.
--SELECT SUM(Ceni.Cena * Orders.Stock),COUNT(*)
--FROM T2012.dbo.sgOrderNeed Orders
--LEFT JOIN dbo.Klas_SMC K ON Orders.SMCId = K.ID
--LEFT JOIN T2014.dbo.Klas_SMC_Ceni Ceni ON Ceni.SMCId = K.ID AND Ceni.NomCena = 0
--WHERE Orders.Stock = -1*Orders.OrderQ AND Orders.OrderQ < 0
/* COGS Sold last week */
SELECT SUM(IndividualSMC.COGS)
FROM
(SELECT K.ID AS SMCId,K.Ime1,SUM(DtKt.Kol) AS Kol, 
        SUM(DtKt.ProdSt_K) AS Revenue, SUM(DtKt.Suma) AS COGS, SUM(DtKt.ProdSt_K) - SUM(DtKt.Suma) AS GP,
        ISNULL(STDEV(DtKt.Kol)*MONTH(GETDATE())/12,0) AS StdevKol, AVG(DtKt.Kol)*MONTH(GETDATE())/12 AS AvgKol
FROM T2014.dbo.[View ReportGenerator Dvig SourceDtKt] DtKt
INNER JOIN T2014.dbo.Klas_SMC K ON DtKt.Dt_SMCId = K.ID
INNER JOIN T2014.dbo.SmetkoPlan KtSP ON KtSP.ID = DtKt.Kt_SP_SmetkaId
INNER JOIN T2014.dbo.SmetkoPlan DtSp ON DtSP.ID = DtKt.Dt_SP_SmetkaId
WHERE  ((DtSP.Smetka >= 700 AND DtSP.Smetka < 710) OR (DtSP.Smetka >= 7000 AND DtSP.Smetka < 7100)) AND K.Kod1 NOT LIKE '99000000%'
   AND ((KtSP.Smetka >= 300 AND KtSP.Smetka < 310) OR (KtSP.Smetka >= 3000 AND KtSP.Smetka < 3100)) 
   AND DtKt.Data >= DATEADD(DAY,-7,GETDATE()) AND DtKt.Data < GETDATE()
   AND DtKt.Podelenie1 <> 4 AND DtKt.Podelenie1 <> 21
GROUP BY K.ID,K.Ime1) IndividualSMC
--Total Stock Lookup
SELECT SUM(Active.OtchCena * Active.QTY) FROM
(
SELECT SUM(SD.QTY) AS QTY, K.Kod1 AS Kod, K.Ime1 as Ime, ISNULL(Ceni.Cena,0)/1.1 AS OtchCena
FROM dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
INNER JOIN T2014.dbo.Klas_SMC_Ceni Ceni ON Ceni.SMCId = K.ID AND Ceni.NomCena = 0
LEFT JOIN T2012.dbo.sgQualityScores QS ON QS.SMCId = K.ID
WHERE SD.Store IN (
	SELECT  Id = 8
	UNION
	SELECT  Id = 239
    UNION
    SELECT  Id = 245
    UNION
    SELECT  Id = 215
    UNION
    SELECT  Id = 279
    UNION
	SELECT  Id 
	FROM    dbo.MOL_Nashi 
	WHERE   ID_Podchinenie = 8
) AND SD.Period < 9 AND QS.SMCId IS NULL  --Flip on or off to get dead stock.
GROUP BY SD.Iv, K.Kod1, K.Ime1,Ceni.Cena HAVING SUM(SD.QTY)>0) Active;
/*
* REMEMBER TO COMMIT!!!!!!!!!!!!!!!!!!!!!!!!!!
*/





/* 2013 Dead Stock */
/* LTM Sales Quantity */
SELECT LTM.SMCId AS SMCId,SUM(LTM.Kol) AS Kol
FROM
	(SELECT Almost.SMCID AS SMCId, SUM(Almost.Kol) AS Kol
	FROM
	(SELECT K.ID AS SMCId,K.Ime1,SUM(DtKt.Kol) AS Kol
	FROM T2014.dbo.[View ReportGenerator Dvig SourceDtKt] DtKt
	INNER JOIN T2014.dbo.Klas_SMC K ON DtKt.Dt_SMCId = K.ID	
	INNER JOIN T2014.dbo.SmetkoPlan KtSP ON KtSP.ID = DtKt.Kt_SP_SmetkaId
	INNER JOIN T2014.dbo.SmetkoPlan DtSp ON DtSP.ID = DtKt.Dt_SP_SmetkaId
	INNER JOIN T2014.dbo.MOL_Nashi MOL ON MOL.ID = DtKt.Kt_MOLNashID
	WHERE  ((DtSP.Smetka >= 700 AND DtSP.Smetka < 710) OR (DtSP.Smetka >= 7000 AND DtSP.Smetka < 7100)) AND K.Kod1 NOT LIKE '99000000%'
   		AND ((KtSP.Smetka >= 300 AND KtSP.Smetka < 310) OR (KtSP.Smetka >= 3000 AND KtSP.Smetka < 3100)) AND DtKt.Data >= '20140101' AND DtKt.Data < GETDATE()
   		AND DtKt.Podelenie1 <> 4 AND DtKt.Podelenie1 <> 21 --AND DtKt.Kt_MOLNashID = 278 --AND K.ID = 2681496
	GROUP BY K.ID,K.Ime1,DtKt.Kt_MOLNashID,MOL.ID_Podchinenie
	) Almost
	GROUP BY Almost.SMCID,Almost.Ime1
UNION ALL
	SELECT Almost1.SMCID AS SMCId,
       SUM(Almost1.Kol) AS Kol
      FROM
	(SELECT K.ID AS SMCId,K.Ime1,SUM(DtKt.Kol) AS Kol, 
        SUM(DtKt.ProdSt_K) AS Revenue, SUM(DtKt.Suma) AS COGS, SUM(DtKt.ProdSt_K) - SUM(DtKt.Suma) AS GP,COUNT(*) AS TransCount,
        CASE WHEN DtKt.Kt_MOLNashID = 8 OR MOL.ID_Podchinenie = 8 THEN SUM(DtKt.Kol) END AS SofiaKol,
        CASE WHEN DtKt.Kt_MOLNashID = 278 THEN SUM(DtKt.Kol) END AS VTKol,
        CASE WHEN DtKt.Kt_MOLNashID = 239 THEN SUM(DtKt.Kol) END AS ByalaKol,
        CASE WHEN DtKt.Kt_MOLNashID = 245 THEN SUM(DtKt.Kol) END AS RuseKol,
        CASE WHEN (DtKt.Kt_MOLNashID = 279 OR DtKt.Kt_MOLNashID = 215) THEN SUM(DtKt.Kol) END AS VarnaKol
	FROM T2013.dbo.[View ReportGenerator Dvig SourceDtKt] DtKt
	INNER JOIN T2013.dbo.Klas_SMC K ON DtKt.Dt_SMCId = K.ID	
	INNER JOIN T2013.dbo.SmetkoPlan KtSP ON KtSP.ID = DtKt.Kt_SP_SmetkaId
	INNER JOIN T2013.dbo.SmetkoPlan DtSp ON DtSP.ID = DtKt.Dt_SP_SmetkaId
	INNER JOIN T2013.dbo.MOL_Nashi MOL ON MOL.ID = DtKt.Kt_MOLNashID
	WHERE  ((DtSP.Smetka >= 700 AND DtSP.Smetka < 710) OR (DtSP.Smetka >= 7000 AND DtSP.Smetka < 7100)) AND K.Kod1 NOT LIKE '99000000%'
   		AND ((KtSP.Smetka >= 300 AND KtSP.Smetka < 310) OR (KtSP.Smetka >= 3000 AND KtSP.Smetka < 3100)) AND DtKt.Data >= DATEADD(year,-1,GETDATE()) AND DtKt.Data < '20140101'
   		AND DtKt.Podelenie1 <> 4 AND DtKt.Podelenie1 <> 21 --AND DtKt.Kt_MOLNashID = 278 --AND K.ID = 2681496
	GROUP BY K.ID,K.Ime1,DtKt.Kt_MOLNashID,MOL.ID_Podchinenie
	) Almost1
	GROUP BY Almost1.SMCID) LTM
GROUP BY LTM.SMCId;






/* Dead Stock Lookup */
SELECT K.Kod1 AS Kod, K.Ime1 as Ime, RealLTM.Kol AS Kol,ISNULL(Ceni.Cena,0) AS OtchCena,SUM(SD.QTY) AS QTY,SUM(SD.QTY)*ISNULL(Ceni.Cena,0) AS Stoinost
     /* SUM(CASE WHEN SD.Store = 8 OR MOL.ID_Podchinenie = 8 THEN SD.QTY ELSE 0 END) AS SofiaStock,
       SUM(CASE WHEN SD.Store = 279 OR SD.Store = 215 THEN SD.QTY ELSE 0 END) AS VarnaStock,
       SUM(CASE WHEN SD.Store = 245 THEN SD.QTY ELSE 0 END) AS RuseStock,
       SUM(CASE WHEN SD.Store = 239 THEN SD.QTY ELSE 0 END) AS ByalaStock,
       SUM(CASE WHEN SD.Store = 278 THEN SD.QTY ELSE 0 END) AS VTStock,
       SUM(CASE WHEN SD.Store = 214 THEN SD.QTY ELSE 0 END) AS Reklamacia,
       SUM(CASE WHEN SD.Store = 240 THEN SD.QTY ELSE 0 END) AS Obrabotka,
       SUM(CASE WHEN SD.Store = 208 THEN SD.QTY ELSE 0 END) AS Centralen,
       SUM(CASE WHEN SD.Store = 243 THEN SD.QTY ELSE 0 END) AS Vunshni,
       SUM(CASE WHEN SD.Store = 8 THEN SD.QTY ELSE 0 END) AS Sofia */
FROM dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
INNER JOIN T2014.dbo.Klas_SMC_Ceni Ceni ON Ceni.SMCId = K.ID AND Ceni.NomCena = 11
INNER JOIN T2014.dbo.MOL_Nashi MOL ON MOL.ID = SD.Store
LEFT JOIN T2012.dbo.sgQualityScores QS ON QS.SMCId = K.ID
LEFT JOIN
(SELECT LTM.SMCKod AS SMCKod,SUM(LTM.Kol) AS Kol
FROM
	(SELECT Almost.SMCID AS SMCId, Almost.SMCKod AS SMCKod, SUM(Almost.Kol) AS Kol
	FROM
	(SELECT K.ID AS SMCId,K.Kod1 AS SMCKod,K.Ime1,SUM(DtKt.Kol) AS Kol
	FROM T2014.dbo.[View ReportGenerator Dvig SourceDtKt] DtKt
	INNER JOIN T2014.dbo.Klas_SMC K ON DtKt.Dt_SMCId = K.ID	
	INNER JOIN T2014.dbo.SmetkoPlan KtSP ON KtSP.ID = DtKt.Kt_SP_SmetkaId
	INNER JOIN T2014.dbo.SmetkoPlan DtSp ON DtSP.ID = DtKt.Dt_SP_SmetkaId
	INNER JOIN T2014.dbo.MOL_Nashi MOL ON MOL.ID = DtKt.Kt_MOLNashID
	WHERE  ((DtSP.Smetka >= 700 AND DtSP.Smetka < 710) OR (DtSP.Smetka >= 7000 AND DtSP.Smetka < 7100)) AND K.Kod1 NOT LIKE '99000000%'
   		AND ((KtSP.Smetka >= 300 AND KtSP.Smetka < 310) OR (KtSP.Smetka >= 3000 AND KtSP.Smetka < 3100)) AND DtKt.Data >= '20140101' AND DtKt.Data <= '20141031'
   		AND DtKt.Podelenie1 <> 4 AND DtKt.Podelenie1 <> 21 --AND DtKt.Kt_MOLNashID = 278 --AND K.ID = 2681496
	GROUP BY K.ID,K.Ime1,K.Kod1,DtKt.Kt_MOLNashID,MOL.ID_Podchinenie
	) Almost
	GROUP BY Almost.SMCID,Almost.SMCKod
UNION ALL
	SELECT Almost1.SMCID AS SMCId,Almost1.SMCKod AS SMCKod,
       SUM(Almost1.Kol) AS Kol
      FROM
	(SELECT K.ID AS SMCId,K.Ime1,K.Kod1 AS SMCKod,SUM(DtKt.Kol) AS Kol, 
        SUM(DtKt.ProdSt_K) AS Revenue, SUM(DtKt.Suma) AS COGS, SUM(DtKt.ProdSt_K) - SUM(DtKt.Suma) AS GP,COUNT(*) AS TransCount,
        CASE WHEN DtKt.Kt_MOLNashID = 8 OR MOL.ID_Podchinenie = 8 THEN SUM(DtKt.Kol) END AS SofiaKol,
        CASE WHEN DtKt.Kt_MOLNashID = 278 THEN SUM(DtKt.Kol) END AS VTKol,
        CASE WHEN DtKt.Kt_MOLNashID = 239 THEN SUM(DtKt.Kol) END AS ByalaKol,
        CASE WHEN DtKt.Kt_MOLNashID = 245 THEN SUM(DtKt.Kol) END AS RuseKol,
        CASE WHEN (DtKt.Kt_MOLNashID = 279 OR DtKt.Kt_MOLNashID = 215) THEN SUM(DtKt.Kol) END AS VarnaKol
	FROM T2013.dbo.[View ReportGenerator Dvig SourceDtKt] DtKt
	INNER JOIN T2013.dbo.Klas_SMC K ON DtKt.Dt_SMCId = K.ID	
	INNER JOIN T2013.dbo.SmetkoPlan KtSP ON KtSP.ID = DtKt.Kt_SP_SmetkaId
	INNER JOIN T2013.dbo.SmetkoPlan DtSp ON DtSP.ID = DtKt.Dt_SP_SmetkaId
	INNER JOIN T2013.dbo.MOL_Nashi MOL ON MOL.ID = DtKt.Kt_MOLNashID
	WHERE  ((DtSP.Smetka >= 700 AND DtSP.Smetka < 710) OR (DtSP.Smetka >= 7000 AND DtSP.Smetka < 7100)) AND K.Kod1 NOT LIKE '99000000%'
   		AND ((KtSP.Smetka >= 300 AND KtSP.Smetka < 310) OR (KtSP.Smetka >= 3000 AND KtSP.Smetka < 3100)) AND DtKt.Data >= '20131031' AND DtKt.Data < '20140101'
   		AND DtKt.Podelenie1 <> 4 AND DtKt.Podelenie1 <> 21 --AND DtKt.Kt_MOLNashID = 278 --AND K.ID = 2681496
	GROUP BY K.ID,K.Ime1,K.Kod1,DtKt.Kt_MOLNashID,MOL.ID_Podchinenie
	) Almost1
	GROUP BY Almost1.SMCID,Almost1.SMCKod) LTM
GROUP BY LTM.SMCId,LTM.SMCKod) RealLTM ON RealLTM.SMCKod = K.Kod1
WHERE SD.Store IN (
	SELECT  Id 
	FROM    dbo.MOL_Nashi 
	WHERE   Podelenie1 = 6
) AND SD.Period < 11 --AND K.Kod1 = '11133370000274'--Flip on or off to get dead stock.
GROUP BY SD.Iv, K.Kod1, K.Ime1,Ceni.Cena,RealLTM.Kol HAVING SUM(SD.QTY)>0



/* Dead Stock in a single number */
DECLARE @deadStockDate DateTime;
SET @deadStockDate = '20141101'; --Must be the first of a month
SELECT SUM(Stoinost) FROM
(SELECT K.Kod1 AS Kod, K.Ime1 as Ime, ISNULL(RealLTM.Kol,0) AS Kol,ISNULL(Ceni.Cena,0) AS OtchCena,SUM(SD.QTY) AS Stock,SUM(SD.QTY)*ISNULL(Ceni.Cena,0) AS Stoinost
       --SUM(CASE WHEN SD.Store = 8 OR MOL.ID_Podchinenie = 8 THEN SD.QTY ELSE 0 END) AS SofiaStock,
       --SUM(CASE WHEN SD.Store = 279 OR SD.Store = 215 THEN SD.QTY ELSE 0 END) AS VarnaStock,
       --SUM(CASE WHEN SD.Store = 245 THEN SD.QTY ELSE 0 END) AS RuseStock,
       --SUM(CASE WHEN SD.Store = 239 THEN SD.QTY ELSE 0 END) AS ByalaStock,
       --SUM(CASE WHEN SD.Store = 278 THEN SD.QTY ELSE 0 END) AS VTStock,
       --SUM(CASE WHEN SD.Store = 214 THEN SD.QTY ELSE 0 END) AS Reklamacia,
       --SUM(CASE WHEN SD.Store = 240 THEN SD.QTY ELSE 0 END) AS Obrabotka,
       --SUM(CASE WHEN SD.Store = 208 THEN SD.QTY ELSE 0 END) AS Centralen,
       --SUM(CASE WHEN SD.Store = 243 THEN SD.QTY ELSE 0 END) AS Vunshni,
       --SUM(CASE WHEN SD.Store = 8 THEN SD.QTY ELSE 0 END) AS Sofia
FROM T2014.dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
INNER JOIN T2014.dbo.Klas_SMC_Ceni Ceni ON Ceni.SMCId = K.ID AND Ceni.NomCena = 11
INNER JOIN T2014.dbo.MOL_Nashi MOL ON MOL.ID = SD.Store
LEFT JOIN T2012.dbo.sgQualityScores QS ON QS.SMCId = K.ID
LEFT JOIN
(SELECT LTM.SMCKod AS SMCKod,SUM(LTM.Kol) AS Kol
FROM
	(SELECT Almost.SMCID AS SMCId, Almost.SMCKod AS SMCKod, SUM(Almost.Kol) AS Kol
	FROM
	(SELECT K.ID AS SMCId,K.Kod1 AS SMCKod,K.Ime1,SUM(DtKt.Kol) AS Kol
	FROM T2014.dbo.[View ReportGenerator Dvig SourceDtKt] DtKt
	INNER JOIN T2014.dbo.Klas_SMC K ON DtKt.Dt_SMCId = K.ID	
	INNER JOIN T2014.dbo.SmetkoPlan KtSP ON KtSP.ID = DtKt.Kt_SP_SmetkaId
	INNER JOIN T2014.dbo.SmetkoPlan DtSp ON DtSP.ID = DtKt.Dt_SP_SmetkaId
	INNER JOIN T2014.dbo.MOL_Nashi MOL ON MOL.ID = DtKt.Kt_MOLNashID
	WHERE  ((DtSP.Smetka >= 700 AND DtSP.Smetka < 710) OR (DtSP.Smetka >= 7000 AND DtSP.Smetka < 7100)) AND K.Kod1 NOT LIKE '99000000%'
   		AND ((KtSP.Smetka >= 300 AND KtSP.Smetka < 310) OR (KtSP.Smetka >= 3000 AND KtSP.Smetka < 3100)) AND DtKt.Data >= '20140101' AND DtKt.Data < @deadStockDate
   		AND DtKt.Podelenie1 <> 4 AND DtKt.Podelenie1 <> 21 --AND DtKt.Kt_MOLNashID = 278 --AND K.ID = 2681496
	GROUP BY K.ID,K.Ime1,K.Kod1,DtKt.Kt_MOLNashID,MOL.ID_Podchinenie
	) Almost
	GROUP BY Almost.SMCID,Almost.SMCKod
UNION ALL
	SELECT Almost1.SMCID AS SMCId,Almost1.SMCKod AS SMCKod, SUM(Almost1.Kol) AS Kol
      FROM
	(SELECT K.ID AS SMCId,K.Ime1,K.Kod1 AS SMCKod,SUM(DtKt.Kol) AS Kol
	FROM T2013.dbo.[View ReportGenerator Dvig SourceDtKt] DtKt
	INNER JOIN T2013.dbo.Klas_SMC K ON DtKt.Dt_SMCId = K.ID	
	INNER JOIN T2013.dbo.SmetkoPlan KtSP ON KtSP.ID = DtKt.Kt_SP_SmetkaId
	INNER JOIN T2013.dbo.SmetkoPlan DtSp ON DtSP.ID = DtKt.Dt_SP_SmetkaId
	INNER JOIN T2013.dbo.MOL_Nashi MOL ON MOL.ID = DtKt.Kt_MOLNashID
	WHERE  ((DtSP.Smetka >= 700 AND DtSP.Smetka < 710) OR (DtSP.Smetka >= 7000 AND DtSP.Smetka < 7100)) AND K.Kod1 NOT LIKE '99000000%'
   		AND ((KtSP.Smetka >= 300 AND KtSP.Smetka < 310) OR (KtSP.Smetka >= 3000 AND KtSP.Smetka < 3100)) AND DtKt.Data >= DATEADD(year,-1,@deadStockDate) AND DtKt.Data < '20140101'
   		AND DtKt.Podelenie1 <> 4 AND DtKt.Podelenie1 <> 21 --AND DtKt.Kt_MOLNashID = 278 --AND K.ID = 2681496
	GROUP BY K.ID,K.Ime1,K.Kod1,DtKt.Kt_MOLNashID,MOL.ID_Podchinenie
	) Almost1
	GROUP BY Almost1.SMCID,Almost1.SMCKod) LTM
GROUP BY LTM.SMCId,LTM.SMCKod) RealLTM ON RealLTM.SMCKod = K.Kod1
WHERE SD.Store IN (
	SELECT  Id 
	FROM    dbo.MOL_Nashi 
	WHERE   Podelenie1 = 6
) AND SD.Period < MONTH(@deadStockDate) --AND K.Kod1 = '11133370000274'--Flip on or off to get dead stock.
GROUP BY SD.Iv, K.Kod1, K.Ime1,Ceni.Cena,RealLTM.Kol HAVING SUM(SD.QTY)>0) Final
WHERE Final.Kol <=0



/* Dead Stock with accounting for what was in stock a year ago */
SELECT * FROM 
(SELECT SD.Iv AS SMCId,K.Kod1 AS Kod, K.Ime1 as Ime, ISNULL(Ceni.Cena,0) AS OtchCena, SUM(SD.QTY) AS QTY, SUM(SD.QTY)*ISNULL(Ceni.Cena,0) AS Stoinost
FROM T2014.dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
INNER JOIN T2014.dbo.Klas_SMC_Ceni Ceni ON Ceni.SMCId = K.ID AND Ceni.NomCena = 11
WHERE SD.Store IN (
	SELECT  Id 
	FROM    dbo.MOL_Nashi 
	WHERE   Podelenie1 = 6
) AND SD.Period < 11  --AND SD.Period < 9 AND QS.SMCId IS NULL  --Flip on or off to get dead stock.
GROUP BY SD.Iv, K.Kod1, K.Ime1,Ceni.Cena HAVING SUM(SD.QTY)>0) CurrentStock
LEFT JOIN
(SELECT Sd.Iv AS SMCId,K.Kod1 AS Kod, K.Ime1 as Ime, ISNULL(Ceni.Cena,0) AS OtchCena, SUM(SD.QTY) AS QTY, SUM(SD.QTY)*ISNULL(Ceni.Cena,0) AS Stoinost
FROM T2013.dbo.[ViewN Salda] SD
INNER JOIN T2013.dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
INNER JOIN T2013.dbo.Klas_SMC_Ceni Ceni ON Ceni.SMCId = K.ID AND Ceni.NomCena = 11
WHERE SD.Store IN (
	SELECT  Id 
	FROM    dbo.MOL_Nashi 
	WHERE   Podelenie1 = 6
) AND SD.Period < 11  
GROUP BY SD.Iv, K.Kod1, K.Ime1,Ceni.Cena HAVING SUM(SD.QTY)>0) Stock1y ON CurrentStock.SMCId = Stock1y.SMCId
LEFT JOIN
(SELECT LTM.SMCId AS SMCId,LTM.SMCKod AS SMCKod,ISNULL(SUM(LTM.Kol),0) AS Kol
FROM
	(SELECT Almost.SMCID AS SMCId, Almost.SMCKod AS SMCKod, SUM(Almost.Kol) AS Kol
	FROM
	(SELECT K.ID AS SMCId,K.Kod1 AS SMCKod,K.Ime1,SUM(DtKt.Kol) AS Kol
	FROM T2014.dbo.[View ReportGenerator Dvig SourceDtKt] DtKt
	INNER JOIN T2014.dbo.Klas_SMC K ON DtKt.Dt_SMCId = K.ID	
	INNER JOIN T2014.dbo.SmetkoPlan KtSP ON KtSP.ID = DtKt.Kt_SP_SmetkaId
	INNER JOIN T2014.dbo.SmetkoPlan DtSp ON DtSP.ID = DtKt.Dt_SP_SmetkaId
	INNER JOIN T2014.dbo.MOL_Nashi MOL ON MOL.ID = DtKt.Kt_MOLNashID
	WHERE  ((DtSP.Smetka >= 700 AND DtSP.Smetka < 710) OR (DtSP.Smetka >= 7000 AND DtSP.Smetka < 7100)) AND K.Kod1 NOT LIKE '99000000%'
   		AND ((KtSP.Smetka >= 300 AND KtSP.Smetka < 310) OR (KtSP.Smetka >= 3000 AND KtSP.Smetka < 3100)) AND DtKt.Data >= '20140101' AND DtKt.Data <= '20141031'
   		AND DtKt.Podelenie1 <> 4 AND DtKt.Podelenie1 <> 21
	GROUP BY K.ID,K.Ime1,K.Kod1,DtKt.Kt_MOLNashID,MOL.ID_Podchinenie
	) Almost
	GROUP BY Almost.SMCID,Almost.SMCKod
UNION ALL
	SELECT Almost1.SMCID AS SMCId,Almost1.SMCKod AS SMCKod,
       SUM(Almost1.Kol) AS Kol
      FROM
	(SELECT K.ID AS SMCId,K.Ime1,K.Kod1 AS SMCKod,SUM(DtKt.Kol) AS Kol
	FROM T2013.dbo.[View ReportGenerator Dvig SourceDtKt] DtKt
	INNER JOIN T2013.dbo.Klas_SMC K ON DtKt.Dt_SMCId = K.ID	
	INNER JOIN T2013.dbo.SmetkoPlan KtSP ON KtSP.ID = DtKt.Kt_SP_SmetkaId
	INNER JOIN T2013.dbo.SmetkoPlan DtSp ON DtSP.ID = DtKt.Dt_SP_SmetkaId
	INNER JOIN T2013.dbo.MOL_Nashi MOL ON MOL.ID = DtKt.Kt_MOLNashID
	WHERE  ((DtSP.Smetka >= 700 AND DtSP.Smetka < 710) OR (DtSP.Smetka >= 7000 AND DtSP.Smetka < 7100)) AND K.Kod1 NOT LIKE '99000000%'
   		AND ((KtSP.Smetka >= 300 AND KtSP.Smetka < 310) OR (KtSP.Smetka >= 3000 AND KtSP.Smetka < 3100)) AND DtKt.Data >= '20131031' AND DtKt.Data < '20140101'
   		AND DtKt.Podelenie1 <> 4 AND DtKt.Podelenie1 <> 21
	GROUP BY K.ID,K.Ime1,K.Kod1,DtKt.Kt_MOLNashID,MOL.ID_Podchinenie
	) Almost1
	GROUP BY Almost1.SMCID,Almost1.SMCKod) LTM
GROUP BY LTM.SMCId,LTM.SMCKod) RealLTM ON CurrentStock.SMCId = RealLTM.SMCId
--WHERE RealLTM.Kol = 0 AND CurrentStock.QTY > 0 AND Stock1y.QTY > 0





DROP TABLE T2012.dbo.sgScriptLog;
CREATE TABLE T2012.dbo.sgScriptLog
(
    Time DATETIME,
	ScriptName VARCHAR(20) NULL,
	Version INT NULL,
	UserName VARCHAR(20) NULL,
	RunTimeInS INT NULL,
	Param1 VARCHAR(20) NULL,
	Param2 Real NULL,
	Param3 Real NULL,
	Output1 Real NULL,
	Output2 Real NULL
);
DECLARE @versionNum INT, @startTime DATETIME;
SET @versionNum = 15;
DECLARE @bLog BIT;
SET @bLog = 1;
SET @startTime = GetDate();
IF @bLog = 1
BEGIN
	INSERT INTO T2012.dbo.sgScriptLog
	SELECT GetDate() AS Time, 'Purchase Report' AS ScriptName, @versionNum AS Version,USER_NAME() AS UserName,DATEDIFF(s,@startTime,getdate()),NULL,NULL,NULL,NULL
END




SELECT Grupa.GrupaSMC AS GrupaSMC, Grupa.GrupaIme, Grupa.CatalozhenNomer,Linked.SvurzanSMC, Linked.SvurzanIme
FROM 
(SELECT K.Kod1 AS GrupaSMC,K.Ime1 AS GrupaIme,Cat.Kod2 AS CatalozhenNomer FROM
T2014.dbo.Klas_SMC K
FULL OUTER JOIN Klas_SMC_CatalogNo Cat ON Cat.SMCID = K.ID
WHERE K.Kod1 LIKE 'I%' AND K.Aktivno = 1) Grupa
FULL OUTER JOIN
(SELECT K.Kod1 AS SvurzanSMC,K.Ime1 AS SvurzanIme,Cat.Kod2 AS CatalozhenNomer FROM
T2014.dbo.Klas_SMC K
FULL OUTER JOIN Klas_SMC_CatalogNo Cat ON Cat.SMCID = K.ID
--WHERE K.Kod1 NOT LIKE '2231%' AND K.Aktivno = 1) Linked ON Linked.CatalozhenNomer = Grupa.CatalozhenNomer
WHERE K.Kod1 NOT LIKE 'I%' AND K.Aktivno = 1) Linked ON Linked.SvurzanSMC = Grupa.CatalozhenNomer
WHERE Grupa.GrupaSMC IS NOT NULL AND Linked.SvurzanSMC IS NOT NULL
GROUP BY Grupa.GrupaSMC, Grupa.GrupaIme, Grupa.CatalozhenNomer,Linked.SvurzanSMC,Linked.SvurzanIme
ORDER BY Grupa.GrupaSMC

SELECT * FROM
(SELECT LinkedSMC.GrupaSMC AS GroupSMCKod, LinkedSMC.SvurzanSMC AS LinkedSMC,LinkedSMC.ID AS SMCRaw,LinkedSMC.SvurzanIme AS GroupSMCIme,LinkedSMC.SvurzanCena AS PurchasePriceBGN, LinkedSMC.SvurzanLT AS LeadTimeInMonths
FROM
(SELECT Grupa.GrupaSMC AS GrupaSMC, Grupa.GrupaIme AS GrupaIme, Grupa.CatalozhenNomer AS CatalozhenNomer,
       Linked.ID AS ID,Linked.SvurzanSMC AS SvurzanSMC, Linked.SvurzanIme AS SvurzanIme,Linked.CenaO1 AS SvurzanCena,Linked.LeadTimeInMonths AS SvurzanLT
 FROM 
     (SELECT K.Kod1 AS GrupaSMC,K.Ime1 AS GrupaIme,Cat.Kod2 AS CatalozhenNomer 
     FROM
        T2014.dbo.Klas_SMC K
        FULL OUTER JOIN Klas_SMC_CatalogNo Cat ON Cat.SMCID = K.ID
        WHERE K.Kod1 LIKE 'I%' AND K.Aktivno = 1) Grupa
        FULL OUTER JOIN
            (SELECT K.ID AS ID,K.Kod1 AS SvurzanSMC,K.Ime1 AS SvurzanIme,Cat.Kod2 AS CatalozhenNomer,K.CenaO1 AS CenaO1, ISNULL(LT.LeadTime,1) AS LeadTimeInMonths 
            FROM
                T2014.dbo.Klas_SMC K
                FULL OUTER JOIN Klas_SMC_CatalogNo Cat ON Cat.SMCID = K.ID
                LEFT JOIN T2012.dbo.sgLeadTimes LT ON LT.Grupa = K.Grupi
                --WHERE K.Kod1 NOT LIKE '2231%' AND K.Aktivno = 1) Linked ON Linked.CatalozhenNomer = Grupa.CatalozhenNomer
                WHERE K.Kod1 NOT LIKE 'I%' AND K.Aktivno = 1) Linked ON Linked.SvurzanSMC = Grupa.CatalozhenNomer
        WHERE Grupa.GrupaSMC IS NOT NULL AND Linked.SvurzanSMC IS NOT NULL
        GROUP BY Grupa.GrupaSMC, Grupa.GrupaIme, Grupa.CatalozhenNomer,Linked.SvurzanSMC,Linked.ID,Linked.SvurzanIme,Linked.CenaO1,Linked.LeadTimeInMonths
        --ORDER BY Grupa.GrupaSMC
        ) LinkedSMC
UNION ALL
SELECT K.Kod1 AS GroupSMCKod, NULL AS LinkedSMC,K.ID AS SMCRaw,K.Ime1 AS GroupSMCIme, K.CenaO1 AS PurchasePriceBGN,ISNULL(LT.LeadTime,1) AS LeadTimeInMonths
            FROM T2014.dbo.[Klas_SMC] K
            LEFT JOIN T2012.dbo.sgLeadTimes LT ON LT.Grupa = K.Grupi
            WHERE K.Kod1 LIKE 'I%' AND K.Aktivno = 1) Active
ORDER BY GroupSMCKod


