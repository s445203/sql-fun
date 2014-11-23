SELECT COALESCE(AllActive.SMCKod,SofiaInv.SMCKod,ByalaInv.SMCKod,VarnaInv.SMCKod,RuseInv.SMCKod,SofiaM.SMCKod,ByalaM.SMCKod,RuseM.SMCKod,VarnaM.SMCKod,Recent3MonthKol.SMCKod,Prior3MonthKol.SMCKod,Kol2013.SMCKod) AS SMCKod,
       COALESCE(AllActive.SMCIme,SofiaInv.SMCIme,ByalaInv.SMCIme,VarnaInv.SMCIme,RuseInv.SMCIme,SofiaM.SMCIme,ByalaM.SMCIme,RuseM.SMCIme,VarnaM.SMCIme,Recent3MonthKol.SMCIme,Prior3MonthKol.SMCIme,Kol2013.SMCIme) AS SMCIme,
    (ISNULL(SofiaInv.SofiaInv,0) + ISNULL(VarnaInv.VarnaInv,0) + ISNULL(RuseInv.RuseInv,0) + ISNULL(ByalaInv.ByalaInv,0)) AS TotalInv,
    ISNULL(SofiaMin,0) AS SofiaMin,
    ISNULL(SofiaInv.SofiaInv,0) AS SofiaInv,
    ISNULL(VarnaMin,0) AS VarnaMin,
    ISNULL(VarnaInv.VarnaInv,0) AS VarnaInv,
    ISNULL(RuseMin,0) AS RuseMin,
    ISNULL(RuseInv.RuseInv,0) AS RuseInv,
    ISNULL(ByalaMin,0) AS ByalaMin,
    ISNULL(ByalaInv.ByalaInv,0) AS ByalaInv,
    ISNULL(Recent3MonthKol.Kol,0) AS Recent3MonthKol,
    ISNULL(Prior3MonthKol.Kol,0) AS Prior3MonthKol,
    ISNULL(Kol2013.Kol,0) AS 'Prod 2013',
    ISNULL(AllActive.Cena,0) AS SchetovodnaCenaVLeva,
    ISNULL(SofiaM.SofiaMax,0) AS SofiaMax
FROM
(
SELECT K.Kod1 AS SMCKod, K.Ime1 AS SMCIme, K.CenaO1 AS Cena 
FROM dbo.Klas_SMC K WHERE K.Aktivno = 1
AND K.Grupi IN (2610,6120,8700,16661,3110,5000,7555,7700,8900,11126,11129,11146,1115,11156,11166,11167,11171,11173,11177,11179,11187,11193,11202,11206,11207,11208,11209,11212,11222,11266,111421,1114488,760,1120,11221,11143,9988,9999)
) AllActive
FULL OUTER JOIN
(SELECT SUM(SD.QTY) AS SofiaInv, K.Kod1 AS SMCKod, K.Ime1 as SMCIme
FROM dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
WHERE SD.Store IN (
 SELECT  Id = 8 --Sofia
 UNION
 SELECT  Id = 240 --Obrabotka
 UNION
 SELECT  Id 
 FROM    dbo.MOL_Nashi 
 WHERE   ID_Podchinenie = 8
) AND
K.Grupi IN (2610,6120,8700,16661,3110,5000,7555,7700,8900,11126,11129,11146,1115,11156,11166,11167,11171,11173,11177,11179,11187,11193,11202,11206,11207,11208,11209,11212,11222,11266,111421,1114488,760,1120,11221,11143,9988,9999)
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
) AND 
K.Grupi IN (2610,6120,8700,16661,3110,5000,7555,7700,8900,11126,11129,11146,11150,11156,11166,11167,11171,11173,11177,11179,11187,11193,11202,11206,11207,11208,11209,11212,11222,11266,111421,1114488,760,1120,11221,11143,9988,9999)
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
) AND
K.Grupi IN (2610,6120,8700,16661,3110,5000,7555,7700,8900,11126,11129,11146,11150,11156,11166,11167,11171,11173,11177,11179,11187,11193,11202,11206,11207,11208,11209,11212,11222,11266,111421,1114488,760,1120,11221,11143,9988,9999)
GROUP BY SD.Iv, K.Kod1, K.Ime1 HAVING SUM(SD.QTY)>=0) RuseInv ON AllActive.SMCKod = RuseInv.SMCKod
FULL OUTER JOIN
(SELECT SUM(SD.QTY) AS VarnaInv, K.Kod1 AS SMCKod, K.Ime1 as SMCIme
FROM dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
WHERE SD.Store IN (
 SELECT  Id = 215 --Varna
 UNION
 SELECT  Id 
 FROM    dbo.MOL_Nashi 
 WHERE   ID_Podchinenie = 215
) AND
K.Grupi IN (2610,6120,8700,16661,3110,5000,7555,7700,8900,11126,11129,11146,11150,11156,11166,11167,11171,11173,11177,11179,11187,11193,11202,11206,11207,11208,11209,11212,11222,11266,111421,1114488,760,1120,11221,11143,9988,9999)
GROUP BY SD.Iv, K.Kod1, K.Ime1 HAVING SUM(SD.QTY)>=0) VarnaInv ON AllActive.SMCKod = VarnaInv.SMCKod   
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
      K.Grupi IN (2610,6120,8700,16661,3110,5000,7555,7700,8900,11126,11129,11146,11150,11156,11166,11167,11171,11173,11177,11179,11187,11193,11202,11206,11207,11208,11209,11212,11222,11266,111421,1114488,760,1120,11221,11143,9988,9999)
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
      K.Grupi IN (2610,6120,8700,16661,3110,5000,7555,7700,8900,11126,11129,11146,11150,11156,11166,11167,11171,11173,11177,11179,11187,11193,11202,11206,11207,11208,11209,11212,11222,11266,111421,1114488,760,1120,11221,11143,9988,9999)
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
      K.Grupi IN (2610,6120,8700,16661,3110,5000,7555,7700,8900,11126,11129,11146,11150,11156,11166,11167,11171,11173,11177,11179,11187,11193,11202,11206,11207,11208,11209,11212,11222,11266,111421,1114488,760,1120,11221,11143,9988,9999)
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
      K.Grupi IN (2610,6120,8700,16661,3110,5000,7555,7700,8900,11126,11129,11146,11150,11156,11166,11167,11171,11173,11177,11179,11187,11193,11202,11206,11207,11208,11209,11212,11222,11266,111421,1114488,760,1120,11221,11143,9988,9999)
) VarnaM ON AllActive.SMCKod = VarnaM.SMCKod
FULL OUTER JOIN
(
SELECT K.Kod1 AS SMCKod, K.Ime1 AS SMCIme,SUM(FN.Kol) AS Kol
FROM dbo.Fakt F
 INNER JOIN dbo.FaktN FN ON F.ID = FN.FaktId
 INNER JOIN dbo.Klas_SMC K ON K.ID = FN.VidSMC
 WHERE K.Grupi IN (2610,6120,8700,16661,3110,5000,7555,7700,8900,11126,11129,11146,11150,11156,11166,11167,11171,11173,11177,11179,11187,11193,11202,11206,11207,11208,11209,11212,11222,11266,111421,1114488,760,1120,11221,11143,9988,9999)
 AND F.Data >= DATEADD(month, -3, GETDATE()) AND F.Data < GETDATE() AND F.Podelenie1 <> 21
 GROUP BY K.Kod1,K.Ime1) Recent3MonthKol ON AllActive.SMCKod = Recent3MonthKol.SMCKod
FULL OUTER JOIN
(
SELECT K.Kod1 AS SMCKod, K.Ime1 AS SMCIme,SUM(FN.Kol) AS Kol
FROM dbo.Fakt F
 INNER JOIN dbo.FaktN FN ON F.ID = FN.FaktId
 INNER JOIN dbo.Klas_SMC K ON K.ID = FN.VidSMC
 WHERE K.Grupi IN (2610,6120,8700,16661,3110,5000,7555,7700,8900,11126,11129,11146,11150,11156,11166,11167,11171,11173,11177,11179,11187,11193,11202,11206,11207,11208,11209,11212,11222,11266,111421,1114488,760,1120,11221,11143,9988,9999)
 AND F.Data >= DATEADD(month, -6, GETDATE()) AND F.Data < DATEADD(month, -3, GETDATE()) AND F.Podelenie1 <> 21
 GROUP BY K.Kod1,K.Ime1) Prior3MonthKol ON AllActive.SMCKod = Prior3MonthKol.SMCKod
FULL OUTER JOIN
(
SELECT K.Kod1 AS SMCKod, K.Ime1 AS SMCIme,SUM(FN.Kol) AS Kol
FROM T2013.dbo.Fakt F
 INNER JOIN T2013.dbo.FaktN FN ON F.ID = FN.FaktId
 INNER JOIN T2013.dbo.Klas_SMC K ON K.ID = FN.VidSMC
 WHERE K.Grupi IN (2610,6120,8700,16661,3110,5000,7555,7700,8900,11126,11129,11146,11150,11156,11166,11167,11171,11173,11177,11179,11187,11193,11202,11206,11207,11208,11209,11212,11222,11266,111421,1114488,760,1120,11221,11143,9988,9999)
 AND F.Data >= '20130101' AND F.Data < '20140101' AND F.Podelenie1 <> 21
 GROUP BY K.Kod1,K.Ime1) Kol2013 ON AllActive.SMCKod = Kol2013.SMCKod
ORDER BY SMCKod;




