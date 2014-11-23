DECLARE @deadStockDate DateTime;
SET @deadStockDate = '20141001'; --Must be the first of a month
IF NOT OBJECT_ID('tempdb..#sgDeadStockReport') IS NULL DROP TABLE #sgDeadStockReport;
SELECT CurrentStock.SMCId AS SMCId,CurrentStock.Kod AS SMCKod, CurrentStock.Ime AS SMCIme,CurrentStock.OtchCena AS OtchCena,CurrentStock.QTY AS StockNow,Stock1y.QTY AS Stock1y,
       CurrentStock.Stoinost AS Stoinost, Stock1y.Stoinost AS Stoinost1y, ISNULL(RealLTM.Kol,0) AS LTMKol
INTO #sgDeadStockReport	
FROM 
(SELECT SD.Iv AS SMCId,K.Kod1 AS Kod, K.Ime1 as Ime, ISNULL(Ceni.Cena,0) AS OtchCena, SUM(SD.QTY) AS QTY, SUM(SD.QTY)*ISNULL(Ceni.Cena,0) AS Stoinost
FROM T2014.dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
INNER JOIN T2014.dbo.Klas_SMC_Ceni Ceni ON Ceni.SMCId = K.ID AND Ceni.NomCena = 11
WHERE SD.Store IN (
	SELECT  Id 
	FROM    dbo.MOL_Nashi 
	WHERE   Podelenie1 = 6
) AND SD.Period < MONTH(@deadStockDate)
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
) AND SD.Period < MONTH(@deadStockDate) 
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
   		AND ((KtSP.Smetka >= 300 AND KtSP.Smetka < 310) OR (KtSP.Smetka >= 3000 AND KtSP.Smetka < 3100)) AND DtKt.Data >= '20140101' AND DtKt.Data < @deadStockDate
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
   		AND ((KtSP.Smetka >= 300 AND KtSP.Smetka < 310) OR (KtSP.Smetka >= 3000 AND KtSP.Smetka < 3100)) AND DtKt.Data >= DATEADD(year,-1,@deadStockDate) AND DtKt.Data < '20140101'
   		AND DtKt.Podelenie1 <> 4 AND DtKt.Podelenie1 <> 21
	GROUP BY K.ID,K.Ime1,K.Kod1,DtKt.Kt_MOLNashID,MOL.ID_Podchinenie
	) Almost1
	GROUP BY Almost1.SMCID,Almost1.SMCKod) LTM
GROUP BY LTM.SMCId,LTM.SMCKod) RealLTM ON CurrentStock.SMCId = RealLTM.SMCId
WHERE ISNULL(RealLTM.Kol,0) <= 0 AND ISNULL(Stock1y.QTY,0) > 0

--SELECT * FROM #sgDeadStockReport
--SELECT SUM(Stoinost) FROM #sgDeadStockReport

SELECT AllActive.Dostavchik,
	   DeadStock.SMCKod, DeadStock.SMCIme, DeadStock.StockNow,DeadStock.Stock1y,
       DeadStock.Stoinost, DeadStock.Stoinost1y, DeadStock.LTMKol,	
	   ISNULL(Nivo0.Cena,0)*1.2/1.1 AS 'Sredna Otchetna',
    ISNULL(AllActive.Cena,0)*1.2 AS 'Posl.Dost s DDS',
    ISNULL(Nivo0.Cena,0)*1.2 AS 'MDC',
    AllActive.SrednaProdadenaCena AS 'Sredna Prodadena Cena Posl. 12 meseca',
	AllActive.CenaPEdro1*1.2 AS Cena1,
	Nivo5.Cena*1.2 AS Cena5,
	Nivo6.Cena*1.2 AS Cena6,
	Nivo7.Cena*1.2 AS Cena7,
	Nivo8.Cena*1.2 AS Cena8,
	Nivo9.Cena*1.2 AS Cena9,
	Nivo21.Cena*1.2 AS Cena21,
	Nivo22.Cena*1.2 AS Cena22,
	Nivo22.Cena*1.2 AS Cena23,
	Nivo5.Otstupka AS Otstupka5,
	Nivo6.Otstupka AS Otstupka6,
	Nivo7.Otstupka AS Otstupka7,
	Nivo8.Otstupka AS Otstupka8,
	Nivo9.Otstupka AS Otstupka9,
	Nivo21.Otstupka AS Otstupka21,
	Nivo22.Otstupka AS Otstupka22,
	Nivo23.Otstupka AS Otstupka23,
    ISNULL(SofiaMin,0) AS SofiaMin,
    ISNULL(VarnaMin,0) AS VarnaMin,
    ISNULL(RuseMin,0) AS RuseMin,
    ISNULL(ByalaMin,0) AS ByalaMin,
    ISNULL(SofiaInv.SofiaInv,0) AS SofiaInv,
    ISNULL(VarnaInv.VarnaInv,0) AS VarnaInv,
    ISNULL(RuseInv.RuseInv,0) AS RuseInv,
    ISNULL(ByalaInv.ByalaInv,0) AS ByalaInv,
    (ISNULL(SofiaInv.SofiaInv,0) + ISNULL(VarnaInv.VarnaInv,0) + ISNULL(RuseInv.RuseInv,0) + ISNULL(ByalaInv.ByalaInv,0)) AS TotalInv,
    ISNULL(Recent3MonthKol.Kol,0) AS Recent3MonthKol,
    ISNULL(Prior3MonthKol.Kol,0) AS Prior3MonthKol,
    ISNULL(Kol2013.Kol,0) AS 'Prod 2013',
    ISNULL(SofiaM.SofiaMax,0) AS SofiaMax,
	ISNULL(AllActive.Aktivno,0) AS Aktivno
FROM #sgDeadStockReport DeadStock
--FROM (SELECT K.ID AS SMCId,K.Kod1 AS SMCKod FROM dbo.Klas_SMC K WHERE K.Kod1 = '001007000000001') DeadStock
LEFT JOIN
(
SELECT G.Ime AS Dostavchik,K.ID AS SMCId,K.Kod1 AS SMCKod, K.Ime1 AS SMCIme, K.CenaO1 AS Cena, K.Aktivno AS Aktivno, K.CenaPEdro1 AS CenaPEdro1,
       CASE 
            WHEN QS.Kol = 0
               THEN 0 
               ELSE ISNULL(QS.Revenue,0)/ISNULL(QS.Kol,1) 
       END SrednaProdadenaCena 
   FROM dbo.Klas_SMC K 
   LEFT JOIN T2012.dbo.sgQualityScores QS ON QS.SMCId = K.ID
   LEFT JOIN T2014.dbo.Grupi_SMC G ON G.Code = K.Grupi
) AllActive ON AllActive.SMCId = DeadStock.SMCId
LEFT JOIN
(SELECT K.Kod1 AS SMCKod, K.ID AS SMCId, Ceni.Cena AS Cena, Ceni.Procent AS Otstupka
   FROM dbo.Klas_SMC K 
   INNER JOIN T2014.dbo.Klas_SMC_Ceni Ceni ON Ceni.SMCId = K.ID AND Ceni.NomCena = 0
) Nivo0 ON DeadStock.SMCId = Nivo0.SMCId
LEFT JOIN
(SELECT K.Kod1 AS SMCKod, K.ID AS SMCId, Ceni.Cena AS Cena, Ceni.Procent AS Otstupka
   FROM dbo.Klas_SMC K 
   INNER JOIN T2014.dbo.Klas_SMC_Ceni Ceni ON Ceni.SMCId = K.ID AND Ceni.NomCena = 5
) Nivo5 ON DeadStock.SMCId = Nivo5.SMCId
LEFT JOIN
(SELECT K.Kod1 AS SMCKod, K.ID AS SMCId, Ceni.Cena AS Cena, Ceni.Procent AS Otstupka
   FROM dbo.Klas_SMC K 
   INNER JOIN T2014.dbo.Klas_SMC_Ceni Ceni ON Ceni.SMCId = K.ID AND Ceni.NomCena = 6
) Nivo6 ON DeadStock.SMCId = Nivo6.SMCId
LEFT JOIN
(SELECT K.Kod1 AS SMCKod, K.ID AS SMCId, Ceni.Cena AS Cena, Ceni.Procent AS Otstupka
   FROM dbo.Klas_SMC K 
   INNER JOIN T2014.dbo.Klas_SMC_Ceni Ceni ON Ceni.SMCId = K.ID AND Ceni.NomCena = 7
) Nivo7 ON DeadStock.SMCId = Nivo7.SMCId
LEFT JOIN
(SELECT K.Kod1 AS SMCKod, K.ID AS SMCId, Ceni.Cena AS Cena, Ceni.Procent AS Otstupka
   FROM dbo.Klas_SMC K 
   INNER JOIN T2014.dbo.Klas_SMC_Ceni Ceni ON Ceni.SMCId = K.ID AND Ceni.NomCena = 8
) Nivo8 ON DeadStock.SMCId = Nivo8.SMCId
LEFT JOIN
(SELECT K.Kod1 AS SMCKod, K.ID AS SMCId, Ceni.Cena AS Cena, Ceni.Procent AS Otstupka
   FROM dbo.Klas_SMC K 
   INNER JOIN T2014.dbo.Klas_SMC_Ceni Ceni ON Ceni.SMCId = K.ID AND Ceni.NomCena = 9
) Nivo9 ON DeadStock.SMCId = Nivo9.SMCId
LEFT JOIN
(SELECT K.Kod1 AS SMCKod, K.ID AS SMCId, Ceni.Cena AS Cena, Ceni.Procent AS Otstupka
   FROM dbo.Klas_SMC K 
   INNER JOIN T2014.dbo.Klas_SMC_Ceni Ceni ON Ceni.SMCId = K.ID AND Ceni.NomCena = 21 
) Nivo21 ON DeadStock.SMCId = Nivo21.SMCId
LEFT JOIN
(SELECT K.Kod1 AS SMCKod, K.ID AS SMCId, Ceni.Cena AS Cena, Ceni.Procent AS Otstupka
   FROM dbo.Klas_SMC K 
   INNER JOIN T2014.dbo.Klas_SMC_Ceni Ceni ON Ceni.SMCId = K.ID AND Ceni.NomCena = 22
) Nivo22 ON DeadStock.SMCId = Nivo22.SMCId
LEFT JOIN
(SELECT K.Kod1 AS SMCKod, K.ID AS SMCId, Ceni.Cena AS Cena, Ceni.Procent AS Otstupka
   FROM dbo.Klas_SMC K 
   INNER JOIN T2014.dbo.Klas_SMC_Ceni Ceni ON Ceni.SMCId = K.ID AND Ceni.NomCena = 23
) Nivo23 ON DeadStock.SMCId = Nivo22.SMCId
LEFT JOIN
(SELECT SUM(SD.QTY) AS SofiaInv, K.Kod1 AS SMCKod, SD.Iv AS SMCId, K.Ime1 as SMCIme
FROM dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
WHERE SD.Store IN (
 SELECT  Id = 8 --Sofia
 UNION
 SELECT  Id 
 FROM    dbo.MOL_Nashi 
 WHERE   ID_Podchinenie = 8
)
GROUP BY SD.Iv, K.Kod1, K.Ime1 HAVING SUM(SD.QTY)>=0) SofiaInv ON DeadStock.SMCId = SofiaInv.SMCId
LEFT JOIN
(SELECT SUM(SD.QTY) AS ByalaInv, K.Kod1 AS SMCKod, SD.Iv AS SMCId, K.Ime1 as SMCIme
FROM dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
WHERE SD.Store IN (
 SELECT  Id = 239 --Byala
 UNION
 SELECT  Id 
 FROM    dbo.MOL_Nashi 
 WHERE   ID_Podchinenie = 239
) 
GROUP BY SD.Iv, K.Kod1, K.Ime1 HAVING SUM(SD.QTY)>=0) ByalaInv ON DeadStock.SMCId = ByalaInv.SMCId
LEFT JOIN
(SELECT SUM(SD.QTY) AS RuseInv, K.Kod1 AS SMCKod, SD.Iv AS SMCId, K.Ime1 as SMCIme
FROM dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
WHERE SD.Store IN (
 SELECT  Id = 245 --Ruse
 UNION
 SELECT  Id 
 FROM    dbo.MOL_Nashi 
 WHERE   ID_Podchinenie = 245
)
GROUP BY SD.Iv, K.Kod1, K.Ime1 HAVING SUM(SD.QTY)>=0) RuseInv ON DeadStock.SMCId = RuseInv.SMCId
LEFT JOIN
(SELECT SUM(SD.QTY) AS VarnaInv, K.Kod1 AS SMCKod, SD.Iv AS SMCId, K.Ime1 as SMCIme
FROM dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
WHERE SD.Store IN (
 SELECT  Id = 215 --Varna
 UNION
 SELECT  Id 
 FROM    dbo.MOL_Nashi 
 WHERE   ID_Podchinenie = 215
)
GROUP BY SD.Iv, K.Kod1, K.Ime1 HAVING SUM(SD.QTY)>=0) VarnaInv ON DeadStock.SMCId = VarnaInv.SMCId   
LEFT JOIN
(SELECT  K.Kod1 AS SMCKod 
 ,K.ID AS SMCId
 ,K.Ime1 AS SMCIme
 ,M.Ime AS Mol
 ,MinZ AS SofiaMin
 ,MaxZ AS SofiaMax
 FROM dbo.Klas_SMC_Zapasi Z
 INNER JOIN dbo.MOL_Nashi M ON Z.MOL = M.ID
 INNER JOIN  dbo.Klas_SMC K ON Z.SMCID = K.ID
WHERE Z.Podelenie1 = 6 AND 
      Z.MOL  = 8
) SofiaM ON DeadStock.SMCId = SofiaM.SMCId    
LEFT JOIN
(SELECT  K.Kod1 AS SMCKod
 , K.ID AS SMCId
 ,K.Ime1 AS SMCIme
 ,M.Ime AS Mol
 ,MinZ AS ByalaMin
 FROM dbo.Klas_SMC_Zapasi Z
 INNER JOIN dbo.MOL_Nashi M ON Z.MOL = M.ID
 INNER JOIN  dbo.Klas_SMC K ON Z.SMCID = K.ID
WHERE Z.Podelenie1 = 6 AND 
      Z.MOL  = 239
) ByalaM ON ByalaM.SMCId = DeadStock.SMCId
LEFT JOIN
(
SELECT  K.Kod1 AS SMCKod
 , K.ID AS SMCId
 ,K.Ime1 AS SMCIme
 ,M.Ime AS Mol
 ,MinZ AS RuseMin
 FROM dbo.Klas_SMC_Zapasi Z
 INNER JOIN dbo.MOL_Nashi M ON Z.MOL = M.ID
 INNER JOIN  dbo.Klas_SMC K ON Z.SMCID = K.ID
WHERE Z.Podelenie1 = 6 AND 
      Z.MOL  = 245
) RuseM ON DeadStock.SMCId= RuseM.SMCId
LEFT JOIN
(
SELECT  K.Kod1 AS SMCKod
 , K.ID AS SMCId
 ,K.Ime1 AS SMCIme
 ,M.Ime AS Mol
 ,MinZ AS VarnaMin
 FROM dbo.Klas_SMC_Zapasi Z
 INNER JOIN dbo.MOL_Nashi M ON Z.MOL = M.ID
 INNER JOIN  dbo.Klas_SMC K ON Z.SMCID = K.ID
WHERE Z.Podelenie1 = 6 AND 
      Z.MOL  = 215
) VarnaM ON DeadStock.SMCId = VarnaM.SMCId
LEFT JOIN
(
SELECT K.Kod1 AS SMCKod, K.ID AS SMCId, K.Ime1 AS SMCIme,SUM(FN.Kol) AS Kol
FROM dbo.Fakt F
 INNER JOIN dbo.FaktN FN ON F.ID = FN.FaktId
 INNER JOIN dbo.Klas_SMC K ON K.ID = FN.VidSMC
 WHERE F.Data >= DATEADD(month, -3, GETDATE()) AND F.Data < GETDATE() AND F.Podelenie1 <> 21 AND F.Podelenie1 <> 4
 GROUP BY K.Kod1,K.Ime1,K.ID) Recent3MonthKol ON DeadStock.SMCId = Recent3MonthKol.SMCId
LEFT JOIN
(
SELECT K.Kod1 AS SMCKod, K.ID AS SMCId,K.Ime1 AS SMCIme,SUM(FN.Kol) AS Kol
FROM dbo.Fakt F
 INNER JOIN dbo.FaktN FN ON F.ID = FN.FaktId
 INNER JOIN dbo.Klas_SMC K ON K.ID = FN.VidSMC
 WHERE F.Data >= DATEADD(month, -6, GETDATE()) AND F.Data < DATEADD(month, -3, GETDATE()) AND F.Podelenie1 <> 21 AND F.Podelenie1 <> 4
 GROUP BY K.Kod1,K.Ime1,K.ID) Prior3MonthKol ON DeadStock.SMCId = Prior3MonthKol.SMCId
LEFT JOIN
(
SELECT K.Kod1 AS SMCKod, K.ID AS SMCId, K.Ime1 AS SMCIme,SUM(FN.Kol) AS Kol
FROM T2013.dbo.Fakt F
 INNER JOIN T2013.dbo.FaktN FN ON F.ID = FN.FaktId
 INNER JOIN T2013.dbo.Klas_SMC K ON K.ID = FN.VidSMC
 WHERE F.Data >= '20130101' AND F.Data < '20140101' AND F.Podelenie1 <> 21 AND F.Podelenie1 <> 4
 GROUP BY K.Kod1,K.Ime1,K.ID) Kol2013 ON DeadStock.SMCId = Kol2013.SMCId
ORDER BY DeadStock.SMCKod;
