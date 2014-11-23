/* Supplier Analysis */
/* Supplier Analysis */
IF NOT OBJECT_ID('tempdb..#sgSupplierAnalysis')     IS NULL DROP TABLE #sgSupplierAnalysis;
CREATE TABLE #sgSupplierAnalysis
(
	Dostavchik nvarchar(50),
	Stoinost Real, GP Real,Revenue Real, Dupka Real, Margin Real,
	PCofStoinost Real, PCofGP Real, PCofRevenue Real, PCofDupka Real
);
INSERT INTO #sgSupplierAnalysis
SELECT G.Ime AS Dostavchik,SUM(Stock.Stoinost) AS Stoinost,SUM(QS.GP) AS GP,SUM(QS.Revenue) AS Revenue,SUM(Orders.DnevnaZagubaOtDupkaBGN) Dupka,
       Margin = CASE WHEN SUM(QS.Revenue) = 0 THEN 0 ELSE 100 * SUM(QS.GP)/SUM(QS.Revenue) END,
       0 AS PCofStoinost, 0 AS PCofGP, 0 AS PCofRevenue, 0 AS PCofDupka
FROM
T2012.dbo.sgOrderNeed Orders
LEFT JOIN
(SELECT K.ID AS SMCId,SUM(SD.QTY) AS QTY, ISNULL(Ceni.Cena,0) AS OtchCena,SUM(SD.QTY)*ISNULL(Ceni.Cena,0) AS Stoinost
FROM dbo.[ViewN Salda] SD
LEFT JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
LEFT JOIN T2014.dbo.Klas_SMC_Ceni Ceni ON Ceni.SMCId = K.ID AND Ceni.NomCena = 11
WHERE SD.Store IN (
	SELECT  Id 
	FROM    dbo.MOL_Nashi 
	WHERE   Podelenie1 = 6
) --AND SD.Period < 9 AND QS.SMCId IS NULL  --Flip on or off to get dead stock.
GROUP BY K.ID, K.Kod1, K.Ime1,Ceni.Cena HAVING SUM(SD.QTY)>0) Stock ON Orders.SMCId = Stock.SMCId
LEFT JOIN dbo.Klas_SMC K ON K.ID = Orders.SMCId
LEFT JOIN T2014.dbo.Grupi_SMC G ON G.Code = K.Grupi
LEFT JOIN T2012.dbo.sgQualityScores QS ON QS.SMCId = Orders.SMCId
--LEFT JOIN T2012.dbo.sgOrderNeed Orders ON K.ID = Orders.SMCId
GROUP BY G.Ime
ORDER BY Stoinost DESC;
UPDATE #sgSupplierAnalysis
SET PCofStoinost = 100*Stoinost / a.SumOfStoinost
FROM (SELECT SUM(Stoinost) AS SumOfStoinost FROM #sgSupplierAnalysis) a;
UPDATE #sgSupplierAnalysis
SET PCofGP = 100*GP / a.SumOfGP FROM (SELECT SUM(GP) AS SumOfGP FROM #sgSupplierAnalysis) a;
UPDATE #sgSupplierAnalysis
SET PCofrevenue = 100*Revenue / a.SumOfRevenue
FROM(SELECT SUM(Revenue) AS SumOfRevenue FROM #sgSupplierAnalysis) a;
UPDATE #sgSupplierAnalysis
SET PCofDupka = 100*Dupka / a.SumOfDupka
FROM(SELECT SUM(Dupka) AS SumOfDupka FROM #sgSupplierAnalysis) a;

SELECT * FROM #sgSupplierAnalysis --WHERE Margin > 24 ORDER BY PCofDupka DESC


