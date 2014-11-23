DECLARE @SMCKod VARCHAR(20)
SET @SMCKod = '851%'
DECLARE @bLog BIT,@versionNum INT, @startTime DATETIME;
SET @versionNum = 6;
SET @bLog = 1;
SET @startTime = GetDate();
IF NOT OBJECT_ID('tempdb..#sgAllMol')     IS NULL DROP TABLE #sgAllMol;
SELECT COALESCE(AllActive.SMCKod,SofiaInv.SMCKod,ByalaInv.SMCKod,VarnaInv.SMCKod,RuseInv.SMCKod,SofiaM.SMCKod,ByalaM.SMCKod,RuseM.SMCKod,VarnaM.SMCKod,Recent3MonthKol.SMCKod,Prior3MonthKol.SMCKod,Kol2013.SMCKod) AS SMCKod,
       COALESCE(AllActive.SMCIme,SofiaInv.SMCIme,ByalaInv.SMCIme,VarnaInv.SMCIme,RuseInv.SMCIme,SofiaM.SMCIme,ByalaM.SMCIme,RuseM.SMCIme,VarnaM.SMCIme,Recent3MonthKol.SMCIme,Prior3MonthKol.SMCIme,Kol2013.SMCIme) AS SMCIme,
    ISNULL(SofiaMin,0) AS SofiaMin,
    ISNULL(VarnaMin,0) AS VarnaMin,
    ISNULL(RuseMin,0) AS RuseMin,
    ISNULL(ByalaMin,0) AS ByalaMin,
    ISNULL(SofiaInv.SofiaInv,0) AS SofiaInv,
    ISNULL(VarnaInv.VarnaInv,0) AS VarnaInv,
    ISNULL(RuseInv.RuseInv,0) AS RuseInv,
    ISNULL(ByalaInv.ByalaInv,0) AS ByalaInv,
    ISNULL(VTInv.VTInv,0) AS VTInv,
    (ISNULL(SofiaInv.SofiaInv,0) + ISNULL(VarnaInv.VarnaInv,0) + ISNULL(RuseInv.RuseInv,0) + ISNULL(ByalaInv.ByalaInv,0) + ISNULL(VTInv.VTInv,0)) AS TotalInv,
    ISNULL(Recent3MonthKol.Kol,0) AS Recent3MonthKol,
    ISNULL(Prior3MonthKol.Kol,0) AS Prior3MonthKol,
    ISNULL(Kol2013.Kol,0) AS 'Prod 2013',
    ISNULL(AllActive.Cena,0) AS SchetovodnaCenaVLeva,
    ISNULL(SofiaM.SofiaMax,0) AS SofiaMax
INTO #sgAllMol
FROM
(
SELECT K.Kod1 AS SMCKod, K.Ime1 AS SMCIme, K.CenaO1 AS Cena FROM dbo.Klas_SMC K WHERE K.Aktivno = 1 AND K.Kod1 LIKE @SMCKod
) AllActive
FULL OUTER JOIN
(SELECT SUM(SD.QTY) AS SofiaInv, K.Kod1 AS SMCKod, K.Ime1 as SMCIme
FROM dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
WHERE SD.Store IN (
 SELECT  Id = 8 --Sofia
 UNION
 SELECT  Id 
 FROM    dbo.MOL_Nashi 
 WHERE   ID_Podchinenie = 8
) AND K.Kod1 LIKE @SMCKod
GROUP BY SD.Iv, K.Kod1, K.Ime1 HAVING SUM(SD.QTY)>=0) SofiaInv ON AllActive.SMCKod = SofiaInv.SMCKod
FULL OUTER JOIN
(SELECT SUM(SD.QTY) AS ByalaInv, K.Kod1 AS SMCKod, K.Ime1 as SMCIme
FROM dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
WHERE SD.Store IN (
 SELECT  Id = 239 --Byala
 UNION
 SELECT  Id 
 FROM    dbo.MOL_Nashi 
 WHERE   ID_Podchinenie = 239
) AND K.Kod1 LIKE @SMCKod
GROUP BY SD.Iv, K.Kod1, K.Ime1 HAVING SUM(SD.QTY)>=0) ByalaInv ON AllActive.SMCKod = ByalaInv.SMCKod
FULL OUTER JOIN
(SELECT SUM(SD.QTY) AS RuseInv, K.Kod1 AS SMCKod, K.Ime1 as SMCIme
FROM dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
WHERE SD.Store IN (
 SELECT  Id = 245 --Ruse
 UNION
 SELECT  Id 
 FROM    dbo.MOL_Nashi 
 WHERE   ID_Podchinenie = 245
) AND K.Kod1 LIKE @SMCKod
GROUP BY SD.Iv, K.Kod1, K.Ime1 HAVING SUM(SD.QTY)>=0) RuseInv ON AllActive.SMCKod = RuseInv.SMCKod
FULL OUTER JOIN
(SELECT SUM(SD.QTY) AS VarnaInv, K.Kod1 AS SMCKod, K.Ime1 as SMCIme
FROM dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
WHERE SD.Store IN (
 SELECT  Id = 279  --Varna 2
 UNION
 SELECT  Id 
 FROM    dbo.MOL_Nashi 
 WHERE   ID_Podchinenie = 279
) AND K.Kod1 LIKE @SMCKod
GROUP BY SD.Iv, K.Kod1, K.Ime1 HAVING SUM(SD.QTY)>=0) VarnaInv ON AllActive.SMCKod = VarnaInv.SMCKod
FULL OUTER JOIN   
(SELECT SUM(SD.QTY) AS VTInv, K.Kod1 AS SMCKod, K.Ime1 as SMCIme
FROM dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
WHERE SD.Store IN (
 SELECT  Id = 278 --Veliko Turnovo
 UNION
 SELECT  Id 
 FROM    dbo.MOL_Nashi 
 WHERE   ID_Podchinenie = 278
) AND K.Kod1 LIKE @SMCKod
GROUP BY SD.Iv, K.Kod1, K.Ime1 HAVING SUM(SD.QTY)>=0) VTInv ON AllActive.SMCKod = VTInv.SMCKod
FULL OUTER JOIN
(SELECT  K.Kod1 AS SMCKod
 ,K.Ime1 AS SMCIme
 ,M.Ime AS Mol
 ,MinZ AS SofiaMin
 ,MaxZ AS SofiaMax
 FROM dbo.Klas_SMC_Zapasi Z
 INNER JOIN dbo.MOL_Nashi M ON Z.MOL = M.ID
 INNER JOIN  dbo.Klas_SMC K ON Z.SMCID = K.ID
WHERE Z.Podelenie1 = 6 AND 
      Z.MOL  = 8 AND
      K.Kod1  LIKE @SMCKod AND
      K.Grupi = ISNULL(NULLIF(0, 0), K.Grupi)
) SofiaM ON AllActive.SMCKod = SofiaM.SMCKod    
FULL OUTER JOIN
(SELECT  K.Kod1 AS SMCKod
 ,K.Ime1 AS SMCIme
 ,M.Ime AS Mol
 ,MinZ AS ByalaMin
 FROM dbo.Klas_SMC_Zapasi Z
 INNER JOIN dbo.MOL_Nashi M ON Z.MOL = M.ID
 INNER JOIN  dbo.Klas_SMC K ON Z.SMCID = K.ID
WHERE Z.Podelenie1 = 6 AND 
      Z.MOL  = 239 AND
      K.Kod1  LIKE @SMCKod AND
      K.Grupi = ISNULL(NULLIF(0, 0), K.Grupi)
) ByalaM ON ByalaM.SMCKod = AllActive.SMCKod
FULL OUTER JOIN
(
SELECT  K.Kod1 AS SMCKod
 ,K.Ime1 AS SMCIme
 ,M.Ime AS Mol
 ,MinZ AS RuseMin
 FROM dbo.Klas_SMC_Zapasi Z
 INNER JOIN dbo.MOL_Nashi M ON Z.MOL = M.ID
 INNER JOIN  dbo.Klas_SMC K ON Z.SMCID = K.ID
WHERE Z.Podelenie1 = 6 AND 
      Z.MOL  = 245 AND
      K.Kod1  LIKE @SMCKod AND
      K.Grupi = ISNULL(NULLIF(0, 0), K.Grupi)
) RuseM ON AllActive.SMCKod= RuseM.SMCKod
FULL OUTER JOIN
(
SELECT  K.Kod1 AS SMCKod
 ,K.Ime1 AS SMCIme
 ,M.Ime AS Mol
 ,MinZ AS VarnaMin
 FROM dbo.Klas_SMC_Zapasi Z
 INNER JOIN dbo.MOL_Nashi M ON Z.MOL = M.ID
 INNER JOIN  dbo.Klas_SMC K ON Z.SMCID = K.ID
WHERE Z.Podelenie1 = 6 AND 
      Z.MOL  = 215 AND
      K.Kod1  LIKE @SMCKod AND
      K.Grupi = ISNULL(NULLIF(0, 0), K.Grupi)
) VarnaM ON AllActive.SMCKod = VarnaM.SMCKod
FULL OUTER JOIN
(
SELECT K.Kod1 AS SMCKod, K.Ime1 AS SMCIme,SUM(FN.Kol) AS Kol
FROM dbo.Fakt F
 INNER JOIN dbo.FaktN FN ON F.ID = FN.FaktId
 INNER JOIN dbo.Klas_SMC K ON K.ID = FN.VidSMC
 WHERE K.Kod1 LIKE @SMCKod 
 AND F.Data >= DATEADD(month, -3, GETDATE()) AND F.Data < GETDATE() AND F.Podelenie1 <> 21 AND F.Podelenie1 <> 4
 GROUP BY K.Kod1,K.Ime1) Recent3MonthKol ON AllActive.SMCKod = Recent3MonthKol.SMCKod
FULL OUTER JOIN
(
SELECT K.Kod1 AS SMCKod, K.Ime1 AS SMCIme,SUM(FN.Kol) AS Kol
FROM dbo.Fakt F
 INNER JOIN dbo.FaktN FN ON F.ID = FN.FaktId
 INNER JOIN dbo.Klas_SMC K ON K.ID = FN.VidSMC
 WHERE K.Kod1 LIKE @SMCKod
 AND F.Data >= DATEADD(month, -6, GETDATE()) AND F.Data < DATEADD(month, -3, GETDATE()) AND F.Podelenie1 <> 21 AND F.Podelenie1 <> 4
 GROUP BY K.Kod1,K.Ime1) Prior3MonthKol ON AllActive.SMCKod = Prior3MonthKol.SMCKod
FULL OUTER JOIN
(
SELECT K.Kod1 AS SMCKod, K.Ime1 AS SMCIme,SUM(FN.Kol) AS Kol
FROM T2013.dbo.Fakt F
 INNER JOIN T2013.dbo.FaktN FN ON F.ID = FN.FaktId
 INNER JOIN T2013.dbo.Klas_SMC K ON K.ID = FN.VidSMC
 WHERE K.Kod1 LIKE @SMCKod
 AND F.Data >= '20130101' AND F.Data < '20140101' AND F.Podelenie1 <> 21 AND F.Podelenie1 <> 4
 GROUP BY K.Kod1,K.Ime1) Kol2013 ON AllActive.SMCKod = Kol2013.SMCKod;
IF @bLog = 1
BEGIN
	INSERT INTO T2012.dbo.sgScriptLog
	SELECT GetDate() AS Time, 'AllMol' AS ScriptName, @versionNum AS Version,USER_NAME() AS UserName,DATEDIFF(s,@startTime,getdate()),@SMCKod,NULL,NULL,NULL,NULL
END
SELECT * FROM #sgAllMol;



