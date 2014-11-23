/*
 * OPISANIE:  Smeni SMCKod s grupata koiato iskash.  Mozhe i '%' da slozhish za da
 *            iskarash vsichki, ama Alma shte kupe dosta v tozi sluchai.
 *
 *  Izvazhda vsichki kolonki nuzhni za ceno-obrazuvane.  
 */
/*
 * VERSION: 4
 *
 * Release History:
 * VERSION 5: 5.11.2014   Added the name of the group from which the SMC is.
 * VERSION 4: 16.10.2014  Fixed SofiaInv bug (was adding mezhdinen and obrabotka)
 * VERSION 3: 27.07.2014 Changed FULL OUTERS to LEFTs and added aktivno filter everywhere to only show Actve SMC
 *                       Expanded list to show Active SMCs with zero price.
 * VERSION 2: 27.07.2014 Fixed divide by zero error for dead stock.
 * VERSION 1: 23.07.2014 Initial release.  Display columns necessary for pricing.
 */
DECLARE @SMCKod VARCHAR(20)
SET @SMCKod = '444%'
DECLARE @bLog BIT,@versionNum INT, @startTime DATETIME;
SET @versionNum = 6;
SET @bLog = 1;
SET @startTime = GetDate();
IF NOT OBJECT_ID('tempdb..#sgCenoObrazuvane')     IS NULL DROP TABLE #sgCenoObrazuvane;
SELECT AllActive.Dostavchik,
	   COALESCE(AllActive.SMCKod,SofiaInv.SMCKod,ByalaInv.SMCKod,VarnaInv.SMCKod,RuseInv.SMCKod,SofiaM.SMCKod,ByalaM.SMCKod,RuseM.SMCKod,VarnaM.SMCKod,Recent3MonthKol.SMCKod,Prior3MonthKol.SMCKod,Kol2013.SMCKod) AS SMCKod,
       COALESCE(AllActive.SMCIme,SofiaInv.SMCIme,ByalaInv.SMCIme,VarnaInv.SMCIme,RuseInv.SMCIme,SofiaM.SMCIme,ByalaM.SMCIme,RuseM.SMCIme,VarnaM.SMCIme,Recent3MonthKol.SMCIme,Prior3MonthKol.SMCIme,Kol2013.SMCIme) AS SMCIme,
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
INTO #sgCenoObrazuvane
FROM
(
SELECT G.Ime AS Dostavchik,K.Kod1 AS SMCKod, K.Ime1 AS SMCIme, K.CenaO1 AS Cena, K.Aktivno AS Aktivno, K.CenaPEdro1 AS CenaPEdro1,
       CASE 
            WHEN QS.Kol = 0
               THEN 0 
               ELSE ISNULL(QS.Revenue,0)/ISNULL(QS.Kol,1) 
       END SrednaProdadenaCena 
   FROM dbo.Klas_SMC K 
   LEFT JOIN T2012.dbo.sgQualityScores QS ON QS.SMCId = K.ID
   LEFT JOIN T2014.dbo.Grupi_SMC G ON G.Code = K.Grupi
   WHERE K.Kod1 LIKE @SMCKod --AND K.CenaPEdro1 > 0 
) AllActive
LEFT JOIN
(SELECT K.Kod1 AS SMCKod, Ceni.Cena AS Cena, Ceni.Procent AS Otstupka
   FROM dbo.Klas_SMC K 
   INNER JOIN T2014.dbo.Klas_SMC_Ceni Ceni ON Ceni.SMCId = K.ID AND Ceni.NomCena = 0
   WHERE K.Kod1 LIKE @SMCKod 
) Nivo0 ON AllActive.SMCKod = Nivo0.SMCKod
LEFT JOIN
(SELECT K.Kod1 AS SMCKod, Ceni.Cena AS Cena, Ceni.Procent AS Otstupka
   FROM dbo.Klas_SMC K 
   INNER JOIN T2014.dbo.Klas_SMC_Ceni Ceni ON Ceni.SMCId = K.ID AND Ceni.NomCena = 5
   WHERE K.Kod1 LIKE @SMCKod 
) Nivo5 ON AllActive.SMCKod = Nivo5.SMCKod
LEFT JOIN
(SELECT K.Kod1 AS SMCKod, Ceni.Cena AS Cena, Ceni.Procent AS Otstupka
   FROM dbo.Klas_SMC K 
   INNER JOIN T2014.dbo.Klas_SMC_Ceni Ceni ON Ceni.SMCId = K.ID AND Ceni.NomCena = 6
   WHERE K.Kod1 LIKE @SMCKod 
) Nivo6 ON AllActive.SMCKod = Nivo6.SMCKod
LEFT JOIN
(SELECT K.Kod1 AS SMCKod, Ceni.Cena AS Cena, Ceni.Procent AS Otstupka
   FROM dbo.Klas_SMC K 
   INNER JOIN T2014.dbo.Klas_SMC_Ceni Ceni ON Ceni.SMCId = K.ID AND Ceni.NomCena = 7
   WHERE K.Kod1 LIKE @SMCKod 
) Nivo7 ON AllActive.SMCKod = Nivo7.SMCKod
LEFT JOIN
(SELECT K.Kod1 AS SMCKod, Ceni.Cena AS Cena, Ceni.Procent AS Otstupka
   FROM dbo.Klas_SMC K 
   INNER JOIN T2014.dbo.Klas_SMC_Ceni Ceni ON Ceni.SMCId = K.ID AND Ceni.NomCena = 8
   WHERE K.Kod1 LIKE @SMCKod 
) Nivo8 ON AllActive.SMCKod = Nivo8.SMCKod
LEFT JOIN
(SELECT K.Kod1 AS SMCKod, Ceni.Cena AS Cena, Ceni.Procent AS Otstupka
   FROM dbo.Klas_SMC K 
   INNER JOIN T2014.dbo.Klas_SMC_Ceni Ceni ON Ceni.SMCId = K.ID AND Ceni.NomCena = 9
   WHERE K.Kod1 LIKE @SMCKod 
) Nivo9 ON AllActive.SMCKod = Nivo9.SMCKod
LEFT JOIN
(SELECT K.Kod1 AS SMCKod, Ceni.Cena AS Cena, Ceni.Procent AS Otstupka
   FROM dbo.Klas_SMC K 
   INNER JOIN T2014.dbo.Klas_SMC_Ceni Ceni ON Ceni.SMCId = K.ID AND Ceni.NomCena = 21
   WHERE K.Kod1 LIKE @SMCKod 
) Nivo21 ON AllActive.SMCKod = Nivo21.SMCKod
LEFT JOIN
(SELECT K.Kod1 AS SMCKod, Ceni.Cena AS Cena, Ceni.Procent AS Otstupka
   FROM dbo.Klas_SMC K 
   INNER JOIN T2014.dbo.Klas_SMC_Ceni Ceni ON Ceni.SMCId = K.ID AND Ceni.NomCena = 22
   WHERE K.Kod1 LIKE @SMCKod 
) Nivo22 ON AllActive.SMCKod = Nivo22.SMCKod
LEFT JOIN
(SELECT K.Kod1 AS SMCKod, Ceni.Cena AS Cena, Ceni.Procent AS Otstupka
   FROM dbo.Klas_SMC K 
   INNER JOIN T2014.dbo.Klas_SMC_Ceni Ceni ON Ceni.SMCId = K.ID AND Ceni.NomCena = 23
   WHERE K.Kod1 LIKE @SMCKod 
) Nivo23 ON AllActive.SMCKod = Nivo22.SMCKod
LEFT JOIN
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
LEFT JOIN
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
LEFT JOIN
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
LEFT JOIN
(SELECT SUM(SD.QTY) AS VarnaInv, K.Kod1 AS SMCKod, K.Ime1 as SMCIme
FROM dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
WHERE SD.Store IN (
 SELECT  Id = 215 --Varna
 UNION
 SELECT  Id 
 FROM    dbo.MOL_Nashi 
 WHERE   ID_Podchinenie = 215
) AND K.Kod1 LIKE @SMCKod 
GROUP BY SD.Iv, K.Kod1, K.Ime1 HAVING SUM(SD.QTY)>=0) VarnaInv ON AllActive.SMCKod = VarnaInv.SMCKod   
LEFT JOIN
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
      K.Kod1  LIKE @SMCKod
) SofiaM ON AllActive.SMCKod = SofiaM.SMCKod    
LEFT JOIN
(SELECT  K.Kod1 AS SMCKod
 ,K.Ime1 AS SMCIme
 ,M.Ime AS Mol
 ,MinZ AS ByalaMin
 FROM dbo.Klas_SMC_Zapasi Z
 INNER JOIN dbo.MOL_Nashi M ON Z.MOL = M.ID
 INNER JOIN  dbo.Klas_SMC K ON Z.SMCID = K.ID
WHERE Z.Podelenie1 = 6 AND 
      Z.MOL  = 239 AND
      K.Kod1  LIKE @SMCKod
) ByalaM ON ByalaM.SMCKod = AllActive.SMCKod
LEFT JOIN
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
      K.Kod1  LIKE @SMCKod
) RuseM ON AllActive.SMCKod= RuseM.SMCKod
LEFT JOIN
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
      K.Kod1  LIKE @SMCKod
) VarnaM ON AllActive.SMCKod = VarnaM.SMCKod
LEFT JOIN
(
SELECT K.Kod1 AS SMCKod, K.Ime1 AS SMCIme,SUM(FN.Kol) AS Kol
FROM dbo.Fakt F
 INNER JOIN dbo.FaktN FN ON F.ID = FN.FaktId
 INNER JOIN dbo.Klas_SMC K ON K.ID = FN.VidSMC
 WHERE K.Kod1 LIKE @SMCKod 
 AND F.Data >= DATEADD(month, -3, GETDATE()) AND F.Data < GETDATE() AND F.Podelenie1 <> 21 AND F.Podelenie1 <> 4
 GROUP BY K.Kod1,K.Ime1) Recent3MonthKol ON AllActive.SMCKod = Recent3MonthKol.SMCKod
LEFT JOIN
(
SELECT K.Kod1 AS SMCKod, K.Ime1 AS SMCIme,SUM(FN.Kol) AS Kol
FROM dbo.Fakt F
 INNER JOIN dbo.FaktN FN ON F.ID = FN.FaktId
 INNER JOIN dbo.Klas_SMC K ON K.ID = FN.VidSMC
 WHERE K.Kod1 LIKE @SMCKod 
 AND F.Data >= DATEADD(month, -6, GETDATE()) AND F.Data < DATEADD(month, -3, GETDATE()) AND F.Podelenie1 <> 21 AND F.Podelenie1 <> 4
 GROUP BY K.Kod1,K.Ime1) Prior3MonthKol ON AllActive.SMCKod = Prior3MonthKol.SMCKod
LEFT JOIN
(
SELECT K.Kod1 AS SMCKod, K.Ime1 AS SMCIme,SUM(FN.Kol) AS Kol
FROM T2013.dbo.Fakt F
 INNER JOIN T2013.dbo.FaktN FN ON F.ID = FN.FaktId
 INNER JOIN T2013.dbo.Klas_SMC K ON K.ID = FN.VidSMC
 WHERE K.Kod1 LIKE @SMCKod 
 AND F.Data >= '20130101' AND F.Data < '20140101' AND F.Podelenie1 <> 21 AND F.Podelenie1 <> 4
 GROUP BY K.Kod1,K.Ime1) Kol2013 ON AllActive.SMCKod = Kol2013.SMCKod
ORDER BY AllActive.SMCKod;

IF @bLog = 1
BEGIN
	INSERT INTO T2012.dbo.sgScriptLog
	SELECT GetDate() AS Time, 'CenoObrazuvane' AS ScriptName, @versionNum AS Version,USER_NAME() AS UserName,DATEDIFF(s,@startTime,getdate()),@SMCKod,NULL,NULL,NULL,NULL
END
SELECT * FROM #sgCenoObrazuvane;


/* GRESHKI - SMCta koito sa aktivni no niamat ceni.
SELECT COALESCE(Greshki.SMCKod,Inv.SMCKod) AS SMC,
       COALESCE(Greshki.Ime,Inv.SMCIme) AS Ime,
       Greshki.Cena AS Cena,
       Inv.Total AS 'Nalichnost Vsichki Obekti',
	   Greshki.Aktivno AS Aktivno
FROM
(SELECT K.Kod1 AS SMCKod, K.Ime1 AS Ime,K.CenaO1 AS 'Posl.Dost.bezDDS',K.Aktivno, Ceni.Cena AS Cena, Ceni.Procent AS Otstupka, K.Aktivno AS Aktivno
   FROM dbo.Klas_SMC K 
   FULL OUTER JOIN T2014.dbo.Klas_SMC_Ceni Ceni ON Ceni.SMCId = K.ID AND Ceni.NomCena = 1
   WHERE K.Aktivno = 1 AND K.Kod1 LIKE '%' AND K.CenaPEdro1 = 0) Greshki
LEFT JOIN
(SELECT SUM(SD.QTY) AS Total, K.Kod1 AS SMCKod, K.Ime1 as SMCIme
FROM dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
WHERE SD.Store IN (
 SELECT  Id = 8 --Sofia
 UNION
 SELECT  Id = 239 --Byala
 UNION
 SELECT  Id = 245 --Ruse
 UNION
 SELECT  Id = 215 --Varna
 UNION
 SELECT  Id = 240 --Obrabotka
 UNION
 SELECT  Id = 242 --Mezhdinen
 UNION
 SELECT  Id 
 FROM    dbo.MOL_Nashi 
 WHERE   ID_Podchinenie = 8
) AND K.Kod1 LIKE '%'
GROUP BY SD.Iv, K.Kod1, K.Ime1 HAVING SUM(SD.QTY)>=0) Inv ON Inv.SMCKod = Greshki.SMCKod
*/




