/*
 * OPISANIE:  Samo go pusni!  Ne pipai Nishto!
 *
 *  Pokazva vsiako SMC koeto spriamo zadadenia srok na dostavka v tablicata na dotavchici v SMCQuality.sql koito
 *  imat nuzhda or poruchka.
 *  Za da se promeniat cifrite, triabva purvo da se pusne SMCQuality.sql skript - toi e osnovniat koito podnoviava
 *  dannite
 */
/*
 * VERSION: 5
 *
 * Release History:
 * VERSION 4: 06.09.2014  Added Veliko Turnovo  
 * VERSION 4: 25.08.2014  Removed old Varna
 * VERSION 3: 13.08.2014  Added Varna 2.
 * VERSION 2: 13.08.2014  Added lots of columns for Sasho.  Also need to specify the SMCKod now.
 * VERSION 1: 23.07.2014 Initial release.  Display the detailed SMC table computed by the quality calculation.
 */
SELECT 
       OrderNeed.*,
       ISNULL(ObrabotkaM.ObrabotkaMin,0) AS 'Komplekt k-vo',
	   ISNULL(SofiaMin,0) AS 'Min SF',
       ISNULL(VarnaMin,0) AS 'Min Varna',
       ISNULL(RuseMin,0) AS 'Min Ruse',
       ISNULL(ByalaMin,0) AS 'Min Byala',
       ISNULL(SofiaInv.SofiaInv,0) AS 'K-vo Sofia',
       ISNULL(VarnaInv.VarnaInv,0) AS 'K-vo Varna',
       ISNULL(RuseInv.RuseInv,0) AS 'K-vo Ruse',
       ISNULL(ByalaInv.ByalaInv,0) AS 'K-vo Byala',
       ISNULL(VTInv.VTInv,0) AS 'K-vo Veliko Turnovo',
       ISNULL(Recent3MonthKol.Kol,0) AS 'A Recent3MonthKol',
       ISNULL(Prior3MonthKol.Kol,0) AS 'B Prior3MonthKol',
       ISNULL(Kol2013.Kol,0) AS '2013',
	   ISNULL(Kol2014.Kol,0) AS '2014'
FROM
(SELECT G.Code AS Grupa,G.Ime AS 'Dostavchik',K.Id AS SMCRaw,K.Kod1 AS 'SMC',K.Ime1 AS 'SMC Ime',Orders.ChistaZaiavka AS 'Nuzhna Poruchka'
FROM T2012.dbo.sgQualityScores QS 
LEFT JOIN T2012.dbo.sgOrderNeed Orders ON QS.SMCId = Orders.SMCId
LEFT JOIN T2014.dbo.Klas_SMC K ON K.ID = QS.SMCID
LEFT JOIN T2014.dbo.Grupi_SMC G ON G.Code = K.Grupi
WHERE Orders.SMCId IS NOT NULL AND Orders.ChistaZaiavka > 0) OrderNeed
LEFT JOIN
(
SELECT  K.ID AS SMCKod
 ,K.Ime1 AS SMCIme
 ,M.Ime AS Mol
 ,MinZ AS ObrabotkaMin
 FROM dbo.Klas_SMC_Zapasi Z
 INNER JOIN dbo.MOL_Nashi M ON Z.MOL = M.ID
 INNER JOIN  dbo.Klas_SMC K ON Z.SMCID = K.ID
WHERE Z.Podelenie1 = 6 AND 
      Z.MOL  = 240
) ObrabotkaM ON OrderNeed.SMCRaw = ObrabotkaM.SMCKod
LEFT JOIN
(SELECT  K.ID AS SMCKod
 ,K.Ime1 AS SMCIme
 ,M.Ime AS Mol
 ,MinZ AS SofiaMin
 ,MaxZ AS SofiaMax --Marian tells me Sofia Max of 0 can be relied on, but this is not the case
 --,99999 AS SofiaMax
 FROM dbo.Klas_SMC_Zapasi Z
 INNER JOIN dbo.MOL_Nashi M ON Z.MOL = M.ID
 INNER JOIN  dbo.Klas_SMC K ON Z.SMCID = K.ID
WHERE Z.Podelenie1 = 6 AND 
      Z.MOL  = 8
) SofiaM ON OrderNeed.SMCRaw = SofiaM.SMCKod
LEFT JOIN
(SELECT  K.ID AS SMCKod
 ,K.Ime1 AS SMCIme
 ,M.Ime AS Mol
 ,MinZ AS ByalaMin
 FROM dbo.Klas_SMC_Zapasi Z
 INNER JOIN dbo.MOL_Nashi M ON Z.MOL = M.ID
 INNER JOIN  dbo.Klas_SMC K ON Z.SMCID = K.ID
WHERE Z.Podelenie1 = 6 AND 
      Z.MOL  = 239
) ByalaM ON ByalaM.SMCKod = OrderNeed.SMCRaw
LEFT JOIN
(
SELECT  K.ID AS SMCKod
 ,K.Ime1 AS SMCIme
 ,M.Ime AS Mol
 ,MinZ AS RuseMin
 FROM dbo.Klas_SMC_Zapasi Z
 INNER JOIN dbo.MOL_Nashi M ON Z.MOL = M.ID
 INNER JOIN  dbo.Klas_SMC K ON Z.SMCID = K.ID
WHERE Z.Podelenie1 = 6 AND 
      Z.MOL  = 245
) RuseM ON OrderNeed.SMCRaw= RuseM.SMCKod
LEFT JOIN
(
SELECT  K.ID AS SMCKod
 ,K.Ime1 AS SMCIme
 ,M.Ime AS Mol
 ,MinZ AS VarnaMin
 FROM dbo.Klas_SMC_Zapasi Z
 INNER JOIN dbo.MOL_Nashi M ON Z.MOL = M.ID
 INNER JOIN  dbo.Klas_SMC K ON Z.SMCID = K.ID
WHERE Z.Podelenie1 = 6 AND 
      Z.MOL  = 215
) VarnaM ON OrderNeed.SMCRaw = VarnaM.SMCKod
LEFT JOIN
(SELECT SUM(SD.QTY) AS SofiaInv, K.ID AS SMCKod, K.Ime1 as SMCIme
FROM dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
WHERE SD.Store IN (
 SELECT  Id = 8 --Sofia
 UNION
 SELECT  Id = 240 --Obrabotka
 UNION
 SELECT  Id = 242 --Mezhdinen
 UNION
 SELECT  Id 
 FROM    dbo.MOL_Nashi 
 WHERE   ID_Podchinenie = 8
)
GROUP BY SD.Iv, K.ID, K.Ime1 HAVING SUM(SD.QTY)>=0) SofiaInv ON OrderNeed.SMCRaw = SofiaInv.SMCKod
LEFT JOIN
(SELECT SUM(SD.QTY) AS ByalaInv, K.ID AS SMCKod, K.Ime1 as SMCIme
FROM dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
WHERE SD.Store IN (
 SELECT  Id = 239 --Byala
 UNION
 SELECT  Id 
 FROM    dbo.MOL_Nashi 
 WHERE   ID_Podchinenie = 239
)
GROUP BY SD.Iv, K.ID, K.Ime1 HAVING SUM(SD.QTY)>=0) ByalaInv ON OrderNeed.SMCRaw = ByalaInv.SMCKod
LEFT JOIN
(SELECT SUM(SD.QTY) AS RuseInv, K.ID AS SMCKod, K.Ime1 as SMCIme
FROM dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
WHERE SD.Store IN (
 SELECT  Id = 245 --Ruse
 UNION
 SELECT  Id 
 FROM    dbo.MOL_Nashi 
 WHERE   ID_Podchinenie = 245
)
GROUP BY SD.Iv, K.ID, K.Ime1 HAVING SUM(SD.QTY)>=0) RuseInv ON OrderNeed.SMCRaw = RuseInv.SMCKod
LEFT JOIN
(SELECT SUM(SD.QTY) AS VarnaInv, K.ID AS SMCKod, K.Ime1 as SMCIme
FROM dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
WHERE SD.Store IN (
 SELECT  Id = 279  --Varna 2
 UNION
 SELECT  Id 
 FROM    dbo.MOL_Nashi 
 WHERE   ID_Podchinenie = 279
)
GROUP BY SD.Iv, K.ID, K.Ime1 HAVING SUM(SD.QTY)>=0) VarnaInv ON OrderNeed.SMCRaw = VarnaInv.SMCKod   
LEFT JOIN
(SELECT SUM(SD.QTY) AS VTInv, K.ID AS SMCKod, K.Ime1 as SMCIme
FROM dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
WHERE SD.Store IN (
 SELECT  Id = 278  --Veliko Turnovo
 UNION
 SELECT  Id 
 FROM    dbo.MOL_Nashi 
 WHERE   ID_Podchinenie = 278
)
GROUP BY SD.Iv, K.ID, K.Ime1 HAVING SUM(SD.QTY)>=0) VTInv ON OrderNeed.SMCRaw = VTInv.SMCKod   
LEFT JOIN
(SELECT K.ID AS SMCKod, K.Ime1 AS SMCIme,SUM(FN.Kol) AS Kol
FROM dbo.Fakt F
 INNER JOIN dbo.FaktN FN ON F.ID = FN.FaktId
 INNER JOIN dbo.Klas_SMC K ON K.ID = FN.VidSMC
 WHERE F.Data >= DATEADD(month, -3, GETDATE()) AND F.Data < GETDATE() AND F.Podelenie1 <> 21 AND F.Podelenie1 <> 4
 GROUP BY K.ID,K.Ime1) Recent3MonthKol ON OrderNeed.SMCRaw = Recent3MonthKol.SMCKod
LEFT JOIN
(
SELECT K.ID AS SMCKod, K.Ime1 AS SMCIme,SUM(FN.Kol) AS Kol
FROM dbo.Fakt F
 INNER JOIN dbo.FaktN FN ON F.ID = FN.FaktId
 INNER JOIN dbo.Klas_SMC K ON K.ID = FN.VidSMC
 WHERE F.Data >= DATEADD(month, -6, GETDATE()) AND F.Data < DATEADD(month, -3, GETDATE()) AND F.Podelenie1 <> 21 AND F.Podelenie1 <> 4
 GROUP BY K.ID,K.Ime1) Prior3MonthKol ON OrderNeed.SMCRaw = Prior3MonthKol.SMCKod
LEFT JOIN
(
SELECT K.ID AS SMCKod, K.Ime1 AS SMCIme,SUM(FN.Kol) AS Kol
FROM T2013.dbo.Fakt F
 INNER JOIN T2013.dbo.FaktN FN ON F.ID = FN.FaktId
 INNER JOIN T2013.dbo.Klas_SMC K ON K.ID = FN.VidSMC
 WHERE F.Data >= '20130101' AND F.Data < '20140101' AND F.Podelenie1 <> 21 AND F.Podelenie1 <> 4
 GROUP BY K.ID,K.Ime1) Kol2013 ON OrderNeed.SMCRaw = Kol2013.SMCKod
LEFT JOIN
(
SELECT K.ID AS SMCKod, K.Ime1 AS SMCIme,SUM(FN.Kol) AS Kol
FROM T2014.dbo.Fakt F
 INNER JOIN T2014.dbo.FaktN FN ON F.ID = FN.FaktId
 INNER JOIN T2014.dbo.Klas_SMC K ON K.ID = FN.VidSMC
 WHERE F.Podelenie1 <> 21 AND F.Podelenie1 <> 4
 GROUP BY K.ID,K.Ime1) Kol2014 ON OrderNeed.SMCRaw = Kol2014.SMCKod	   
ORDER BY OrderNeed.SMC;