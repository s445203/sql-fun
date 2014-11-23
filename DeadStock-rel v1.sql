DECLARE @deadStockDate DateTime;
SET @deadStockDate = '20140101'; --Must be the first of a month
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
SELECT SUM(Stoinost) FROM #sgDeadStockReport