/*
 * OPISANIE:
 * Populni po dolu:
 *    @SMCKod = kod na grupata za koiato iskash da prigovtish zaiavka.
 *    @leadTimeMonths = kolko vreme dostavchika otnema za da napravi dostavka v meseca
 *    @initialOrderBuffer = Skripta poruchva dostatuchno za da ima malichnost za srok
 *                             (vremeto na dostavka ot dostavchika @leadTimeMonths) * (1 + @initialOrderBuffer) 
 *       Primer:  Ako sroka e 2 meseca i @initialOrderBuffer = 0.5, skripta shte smetne dostavka dostatuchna za
 *           3 meseca prodazbi 2*(1+0.5)
 * 
 *    @targetOrderValue = Ako iskash da udulzhish poruchkata za da stignesh do niakoia po visoka stoinost, primerno za
 *                         da platish transporta, slozhi cifrata koiato iskash da poruchash tuk.  Skripta avtomatichno shte
 *                         udulzhi poruchkata, no shte smiata 999999 kato poruchka za 0.  Ako ne iskash udulzhenie, slozhi 0 i skripta 
 *                         shte izvadi poruchka ot koiato sklada ima nuzhda.
 */
DECLARE @SMCKod VARCHAR(20), @targetOrderValue Real, @initialOrderBuffer Real;
DECLARE @bLog BIT,@versionNum INT, @startTime DATETIME;
SET @SMCKod = '373%';       
SET @targetOrderValue = 0;
SET @initialOrderBuffer = 0.5;
SET @versionNum = 99994;
SET @bLog = 1;
SET @startTime = GetDate();
/*
 * VERSION: 17
 *
 * Release History:
 * VERSION 17:  13.11.2014 Added logging
 * VERSION 16:  13.11.2014 Added ClientCount to show clients for this year 
 * VERSION 15:  9.11.2014 Passed maxFaktKol into dailyholecost
 * VERSION 14:  8.11.2014 Added calculation of actual inventory hole cost 
 * VERSION 13: 16.10.2014  Fixed SofiaInv bug (was adding mezhdinen and obrabotka)
 * VERSION 12: 03.10.2014  Added sales by obekt proportion 
 * VERSION 11: 06.09.2014  Added Veliko Turnovo 
 * VERSION 10: 25.08.2014 Got rid of old Varna
 * VERSION 8: 25.08.2014  Changed DailyHoleCost API to reduce errors.
 * VERSION 7: 7.07.2014  Added 2014 column
 * VERSION 6: 1.07.2014  Rewrote CalcOrder to use up to date information.  Lots of API changes.
 * VERSION 5: 31.07.2014  Updated CalcOrder to take in MaxFakt in order to calculate distribution.
 * VERSION 4: 30.07.2014 Updated DailyHoleCost to use actual ltm GP per SMC rather than single blanket figure.
 * VERSION 3:  28.07.2014 - Updated CalcOrder to consider sales in current calendar month.
 * VERSION 2:  25.07.2014 - Changes for komplekt, fixed NewtonRaphson, added podelenie <> 4 filter.
 * VERSION 1: 23.07.2014 Initial release.  Compute a purchase order. 
 */
/*
 *
 */
/*========================================================*/
/*
 * This file pulls all the data needed to make a purchase order from a supplier.
 * The general order is:
 * 1.  Initialise all the data structures needed
 * 2. Copy all of the Fakt table data into #sgSalesHistory.  This is how we
 *     collect everything accross years.  #sgSalesHistory contains the purchased quantity of each
 *     SMC in our date scheme, where Jan2006 is month 1.
 * 3. Then we compute all of the stock data.
 *  3a.  #sgAllSalda is a big union of all the Salda tables for the group we are making a report
 *       this is how we span across multiple years.
 *  3b.  #sgCurrentStock is really the sum of all the salda data.  
 *  3c.  We build the inventory history month by month.  The first month
 *        is current stock right now and this is the first to go on
 *  3d.  Then we compute the delta for the next month. The delta is how much the stock changed by
 *  3e.  We loop for each month, going back further in further in time.  Each loop
 *       is rolling back from today to the month in question.
 *  Finally we have to display our monstrosity in a way which is humanly readable in Excel.
 */
/*
 * 1.  Initialise all the data structures needed
 */
IF NOT OBJECT_ID('tempdb..#sgSalesHistory')     IS NULL DROP TABLE #sgSalesHistory;
IF NOT OBJECT_ID('tempdb..#sgAllSalda')         IS NULL DROP TABLE #sgAllSalda;
IF NOT OBJECT_ID('tempdb..#sgInventoryHistory') IS NULL DROP TABLE #sgInventoryHistory;
IF NOT OBJECT_ID('tempdb..#sgCurrentStock')     IS NULL DROP TABLE #sgCurrentStock;
IF NOT OBJECT_ID('tempdb..#sgMonthDelta')       IS NULL DROP TABLE #sgMonthDelta;
IF NOT OBJECT_ID('tempdb..#sgAdjPurchaseReport') IS NULL DROP TABLE #sgAdjPurchaseReport;
IF NOT OBJECT_ID('tempdb..#sgRelevantSMC')      IS NULL DROP TABLE #sgRelevantSMC;
CREATE TABLE #sgSalesHistory
(
	SMCKod INT NULL,
	Kol Real NULL,
	Month INT NULL,
);
CREATE TABLE #sgAllSalda
(
	Month INT NULL,
	SMCKod INT NULL,
	QTY Real NULL,
	Period INT NULL,
	Year INT NULL,
);
CREATE TABLE #sgCurrentStock
(	Stock REAL NULL,
	SMCKod INT NULL,
	Month INT NULL
);
CREATE TABLE #sgInventoryHistory
(
	Stock REAL NULL,
	SMCKod INT NULL,
	Month INT NULL
);
CREATE TABLE #sgMonthDelta
(
    Delta REAL NULL,
	SMCKod INT NULL,
	Month INT NULL
);
CREATE TABLE #sgRelevantSMC
(
	GroupSMCKod VARCHAR(20) NULL,
	LinkedSMCKod VARCHAR(20) NULL,
	SMCRaw INT NULL,
	GroupSMCIme VARCHAR(70) NULL,
	PurchasePriceBGN DECIMAL NULL,
	LeadTimeInMonths Real NULL
);
CREATE CLUSTERED INDEX sgIdxIH ON #sgInventoryHistory(SMCKod);
CREATE INDEX sgIdxIHMonth ON #sgInventoryHistory(Month);
CREATE CLUSTERED INDEX sgIdxSH ON #sgSalesHistory(SMCKod);
CREATE INDEX sgIdxSHMonth ON #sgSalesHistory(Month);
CREATE CLUSTERED INDEX sgIdxRelevantRaw ON #sgRelevantSMC(SMCRaw);
CREATE CLUSTERED INDEX sgIdxRelevantGroup ON #sgRelevantSMC(GroupSMCKod);
DECLARE @startMonth TINYINT;
DECLARE @currMonth TINYINT;
DECLARE @today DateTime;
DECLARE @currMonthStart DateTime;
DECLARE @today3m DateTime;
DECLARE @today6m DateTime;
/*
 * The first thing we do is buid the list of SMCs we want stock and sales history for
 */
INSERT INTO #sgRelevantSMC
SELECT Grupa.GrupaSMCKod AS GroupSMCKod, 
        Linked.LinkedSMCKod AS LinkedSMCKod,
        Linked.ID AS SMCRaw, 
        Linked.SvurzanIme AS GroupSMCIme,
        Linked.CenaO1 AS PurchasePriceBGN,
        Linked.LeadTimeInMonths AS LeadTimeInMonths
 FROM 
     (SELECT K.Kod1 AS GrupaSMCKod,K.Ime1 AS GrupaIme,Cat.Kod2 AS CatalozhenNomer 
     FROM
        T2014.dbo.Klas_SMC K
        FULL OUTER JOIN Klas_SMC_CatalogNo Cat ON Cat.SMCID = K.ID
        WHERE K.Kod1 LIKE @SMCKod AND K.Aktivno = 1) Grupa
        FULL OUTER JOIN
            (SELECT K.ID AS ID,K.Kod1 AS LinkedSMCKod,K.Ime1 AS SvurzanIme,Cat.Kod2 AS CatalozhenNomer,K.CenaO1 AS CenaO1, ISNULL(LT.LeadTime,1) AS LeadTimeInMonths 
            FROM
                T2014.dbo.Klas_SMC K
                FULL OUTER JOIN Klas_SMC_CatalogNo Cat ON Cat.SMCID = K.ID
                LEFT JOIN T2012.dbo.sgLeadTimes LT ON LT.Grupa = K.Grupi
                WHERE K.Kod1 NOT LIKE @SMCKod AND K.Aktivno = 1) Linked ON Linked.LinkedSMCKod = Grupa.CatalozhenNomer
        WHERE Grupa.GrupaSMCKod IS NOT NULL AND Linked.LinkedSMCKod IS NOT NULL
        GROUP BY Grupa.GrupaSMCKod, Grupa.GrupaIme, Grupa.CatalozhenNomer,Linked.LinkedSMCKod,Linked.ID,Linked.SvurzanIme,Linked.CenaO1,Linked.LeadTimeInMonths
UNION ALL
SELECT K.Kod1 AS GroupSMCKod, NULL AS LinkedSMCKod,K.ID AS SMCRaw,K.Ime1 AS GroupSMCIme, K.CenaO1 AS PurchasePriceBGN,ISNULL(LT.LeadTime,1) AS LeadTimeInMonths
            FROM T2014.dbo.[Klas_SMC] K
            LEFT JOIN T2012.dbo.sgLeadTimes LT ON LT.Grupa = K.Grupi
        WHERE K.Kod1 LIKE @SMCKod AND K.Aktivno = 1
ORDER BY GroupSMCKod,LinkedSMCKod;
/*
 * Jan2006 is month 1 in our scheme
 */
SET @startMonth = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE());
SET @currMonth = @startMonth;
/* 
 * Initiliase Current Sales as Current Month + 1
 */
SET @today = GETDATE();
SET @today3m = DATEADD(month, -3, @today);
SET @today6m = DATEADD(month, -6, @today);
--
SET @currMonthStart = DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0);
/*
 * 2. Copy all of the Fakt table data into #sgSalesHistory.  This is how we
 *     collect everything accross years.  #sgSalesHistory contains the purchased quantity of each
 *     SMC in our date scheme, where Jan2005 is month 1.
 */
WHILE @currMonth > @startMonth - 26
BEGIN
     /*
     * Add the delta from the current month
     */
    IF YEAR(@currMonthStart) = 2014
    BEGIN
        INSERT INTO #sgSalesHistory
	    SELECT FN.VidSMC AS SMCKod,SUM(FN.Kol) AS Kol,@currMonth AS Month
        FROM T2014.dbo.Fakt F
        LEFT JOIN T2014.dbo.FaktN FN ON F.ID = FN.FaktId AND F.Data >= @currMonthStart AND F.Data < DATEADD(month,1,@currMonthStart)
		LEFT JOIN T2014.dbo.Klas_SMC K ON K.Id = FN.VidSMC
		INNER JOIN #sgRelevantSMC Relevant ON Relevant.SMCRaw = K.ID
		WHERE F.Podelenie1 <> 21 AND F.Podelenie1 <> 4 --podelenie1 21 is oferti, which are not real sales.
		--WHERE K.Kod1 LIKE @SMCKod AND F.Podelenie1 <> 21 AND F.Podelenie1 <> 4 --podelenie1 21 is oferti, which are not real sales.
		GROUP BY FN.VidSMC 
    END
    IF YEAR(@currMonthStart) = 2013
    BEGIN
        INSERT INTO #sgSalesHistory
        SELECT FN.VidSMC AS SMCKod,SUM(FN.Kol) AS Kol,@currMonth AS Month
        FROM T2013.dbo.Fakt F
        LEFT JOIN T2013.dbo.FaktN FN ON F.ID = FN.FaktId AND F.Data >= @currMonthStart AND F.Data < DATEADD(month,1,@currMonthStart)
		LEFT JOIN T2014.dbo.Klas_SMC K ON K.Id = FN.VidSMC
		INNER JOIN #sgRelevantSMC Relevant ON Relevant.SMCRaw = K.ID
		WHERE F.Podelenie1 <> 21 AND F.Podelenie1 <> 4 --podelenie1 21 is oferti, which are not real sales.
		--WHERE K.Kod1 LIKE @SMCKod AND F.Podelenie1 <> 21 AND F.Podelenie1 <> 4 --podelenie1 21 is oferti, which are not real sales.
		GROUP BY FN.VidSMC
    END
    IF YEAR(@currMonthStart) = 2012
    BEGIN
        INSERT INTO #sgSalesHistory
        SELECT FN.VidSMC AS SMCKod,SUM(FN.Kol) AS Kol,@currMonth AS Month
        FROM T2012.dbo.Fakt F
        LEFT JOIN T2012.dbo.FaktN FN ON F.ID = FN.FaktId AND F.Data >= @currMonthStart AND F.Data < DATEADD(month,1,@currMonthStart)
		LEFT JOIN T2014.dbo.Klas_SMC K ON K.Id = FN.VidSMC
		INNER JOIN #sgRelevantSMC Relevant ON Relevant.SMCRaw = K.ID
		WHERE F.Podelenie1 <> 21 AND F.Podelenie1 <> 4 --podelenie1 21 is oferti, which are not real sales.
		--WHERE K.Kod1 LIKE @SMCKod AND F.Podelenie1 <> 21 AND F.Podelenie1 <> 4 --podelenie1 21 is oferti, which are not real sales.
		GROUP BY FN.VidSMC
    END
    /*
     * Decrement the two loop counters for next month
     */
    SET @currMonth = @currMonth - 1;
    SET @currMonthStart = DATEADD(month,-1,@currMonthStart)
END;
/*
 * 3. Now compute all of the stock data.
 */
SET @currMonth = @startMonth;
/* 
 *   3a.  #sgAllSalda is a big union of all the Salda tables for the group we are making a report
 *       this is how we span across multiple years.
 */
INSERT INTO #sgAllSalda
SELECT *
FROM
(SELECT 12*(2013-2005)+SD.Period AS Month,SD.Iv AS SMCKod,SD.QTY AS QTY,SD.Period AS Period,2014 AS Year 
FROM T2014.dbo.[ViewN Salda] SD
LEFT JOIN T2014.dbo.[Klas_SMC] K ON SD.Iv = K.ID 
LEFT JOIN T2014.dbo.[MOL_Nashi] M ON M.ID = SD.Store
INNER JOIN #sgRelevantSMC Relevant ON Relevant.SMCRaw = K.ID
WHERE SD.Acc = 98 
AND SD.Store IN (
	SELECT  Id = 8 --Sofia
    UNION
    SELECT  Id = 279  --Varna 2
    UNION
    SELECT  Id = 278  --Veliko Turnovo
    UNION
    SELECT  Id = 245  --Ruse
    UNION
    SELECT  Id = 239 --Byala
    UNION
	SELECT  Id = 240  --Obrabotka
    UNION
    SELECT  Id = 242  --Mezhdinen
    UNION
	SELECT  Id 
	FROM    T2014.dbo.MOL_Nashi 
	WHERE   ID_Podchinenie = 8
)
AND SD.Period <>0) AS S2014
UNION ALL
SELECT * FROM
(SELECT 12*(2012-2005)+SD.Period AS Month,SD.Iv AS SMCKod,SD.QTY AS QTY,SD.Period AS Period,2013 AS Year 
FROM T2013.dbo.[ViewN Salda] SD
LEFT JOIN T2013.dbo.[Klas_SMC] K ON SD.Iv = K.ID 
LEFT JOIN T2013.dbo.[MOL_Nashi] M ON M.ID = SD.Store
INNER JOIN #sgRelevantSMC Relevant ON Relevant.SMCRaw = K.ID
WHERE SD.Acc = 98 
AND SD.Store IN (
	SELECT  Id = 8 --Sofia
    UNION
    SELECT  Id = 279  --Varna 2
    UNION
    SELECT  Id = 278  --Veliko Turnovo
    UNION
    SELECT  Id = 245  --Ruse
    UNION
    SELECT  Id = 239 --Byala
    UNION
	SELECT  Id = 240  --Obrabotka
    UNION
	SELECT  Id = 242  --Mezhdinen
    UNION
	SELECT  Id 
	FROM    T2013.dbo.MOL_Nashi 
	WHERE   ID_Podchinenie = 8
)
AND SD.Period <>0) AS S2013 --Bring forward balance from 2012
UNION ALL
SELECT * FROM (
SELECT 12*(2011-2005)+SD.Period AS Month,SD.Iv AS SMCKod,SD.QTY AS QTY,SD.Period AS Period,2012 AS Year 
FROM T2012.dbo.[ViewN Salda] SD
LEFT JOIN T2012.dbo.[Klas_SMC] K ON SD.Iv = K.ID 
LEFT JOIN T2012.dbo.[MOL_Nashi] M ON M.ID = SD.Store
INNER JOIN #sgRelevantSMC Relevant ON Relevant.SMCRaw = K.ID
WHERE SD.Acc = 98 
AND SD.Store IN (
	SELECT  Id = 8 --Sofia
    UNION
    SELECT  Id = 279  --Varna 2
    UNION
    SELECT  Id = 278  --Veliko Turnovo
    UNION
    SELECT  Id = 245  --Ruse
    UNION
    SELECT  Id = 239 --Byala
    UNION
	SELECT  Id = 240  --Obrabotka
    UNION
	SELECT  Id = 242  --Mezhdinen
    UNION
	SELECT  Id 
	FROM    T2012.dbo.MOL_Nashi 
	WHERE   ID_Podchinenie = 8
)) AS S2012; --The last year we take in must include the sum of all priors which is in period 0 carryover
/* 
 *   3b.  #sgCurrentStock is really the sum of all the salda data.  
 */
INSERT INTO #sgCurrentStock
SELECT SUM(SD.QTY) AS Stock,SD.SMCKod AS SMCKod,@startMonth+1 AS Month
FROM #sgAllSalda SD 
GROUP BY SD.SMCKod;
/* 
 *   3c.  We build the inventory history month by month.  The first month
 *        is current stock right now and this is the first to go on
 */
INSERT INTO #sgInventoryHistory
SELECT CS.Stock AS Stock,CS.SMCKod AS SMCKod,CS.Month AS Month
FROM #sgCurrentStock CS;
/* 
 *   3d.  Then we compute the delta for the next month. The delta is how much the stock changed by
 */
INSERT INTO #sgMonthDelta
SELECT SUM(SD.QTY) AS Delta,SD.SMCKod AS SMCKod,@startMonth AS Month
FROM #sgAllSalda SD 
WHERE SD.Month > @currMonth-1 AND SD.Month <= @startMonth
GROUP BY SD.SMCKod;
/* 
 *   3e.  We loop for each month, going back further in further in time.  Each loop
 *        is rolling back from today to the month in question.
 */
SET @currMonth = @startMonth;
WHILE @currMonth > @startMonth - 26
BEGIN
    /*
     * Add the delta from the current month
     */
    INSERT INTO #sgInventoryHistory
    SELECT ISNULL(CS.Stock,0) - ISNULL(Delta.Delta,0) AS Stock,COALESCE(CS.SMCKod,Delta.SMCKod) AS SMCKod,
    Month = @currMonth
    FROM #sgCurrentStock CS
    FULL OUTER JOIN #sgMonthDelta Delta ON CS.SMCKod = Delta.SMCKod;
     /*
      * Decrement for next month
      */
    SET @currMonth = @currMonth - 1;
    /*
     * Truncate and compute new month delta
     */
    TRUNCATE TABLE #sgMonthDelta;
    INSERT INTO #sgMonthDelta
    SELECT SUM(SD.QTY) AS Delta,SD.SMCKod AS SMCKod,@currMonth-1 AS Month
    FROM #sgAllSalda SD 
    WHERE SD.Month > @currMonth-1 AND SD.Month <= @startMonth
    GROUP BY SD.SMCKod;
END;
/* 
 *   Finally we have to display our monstorsity in a way which is humanly readable in Excel.
 */
SELECT Active.GroupSMCKod AS 'SMC ot Grupa',
 	   Active.LinkedSMCKod AS 'LinkedSMCKod',
       Active.GroupSMCIme AS 'SMC ot Grupa Ime',
       Q.Quality AS 'Kachestvo',
       Active.PurchasePriceBGN AS 'Posl. Dost. Cena bez DDS v lv',
       Cheapest.MinPrice AS 'Nai-evtina Cena',
       ISNULL(Active.LeadTimeInMonths,1) AS 'Meseci za Dostavka',
       @initialOrderBuffer AS 'Buffer',
       Proveri = CASE WHEN (Active.LinkedSMCKod IS NULL AND Q.Quality IS NOT NULL AND ISNULL(SofiaM.SofiaMax,0) = 999999 AND Cheapest.MinPrice < Active.PurchasePriceBGN)
                        OR (Active.LinkedSMCKod IS NULL AND Q.Quality IS NOT NULL AND ISNULL(SofiaM.SofiaMax,0) = 0 AND Cheapest.MinPrice > Active.PurchasePriceBGN) THEN 1
                      ELSE 0 END,
       ISNULL(SofiaM.SofiaMax,0) AS SofiaMax,
       ISNULL(ObrabotkaM.ObrabotkaMin,0) AS 'Komplekt k-vo',
       ISNULL(I0.Stock,0) AS 'Inventar Vsichki Obekti',
	   'Predlozheno k-vo za zaiavka' = dbo.sgCalcOrder(1,1,@initialOrderBuffer,ISNULL(ObrabotkaM.ObrabotkaMin,0),Q.Quality,
											ISNULL(Active.LeadTimeInMonths,1),ISNULL(M0.Kol,0),
											(ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0)),
											(ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0)+ISNULL(M4.Kol,0)+ISNULL(M5.Kol,0)+ISNULL(M6.Kol,0)),
											(ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0)+ISNULL(M4.Kol,0)+ISNULL(M5.Kol,0)+ISNULL(M6.Kol,0)+ISNULL(M7.Kol,0)+ISNULL(M8.Kol,0)+ISNULL(M9.Kol,0)+ISNULL(M10.Kol,0)+ISNULL(M11.Kol,0)+ISNULL(M12.Kol,0)),
											(ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0)+ISNULL(M4.Kol,0)+ISNULL(M5.Kol,0)+ISNULL(M6.Kol,0)+ISNULL(M7.Kol,0)+ISNULL(M8.Kol,0)+ISNULL(M9.Kol,0)+ISNULL(M10.Kol,0)+ISNULL(M11.Kol,0)+ISNULL(M12.Kol,0)
	              	  						+ISNULL(M13.Kol,0)+ISNULL(M14.Kol,0)+ISNULL(M15.Kol,0)+ISNULL(M16.Kol,0)+ISNULL(M17.Kol,0)+ISNULL(M18.Kol,0)+ISNULL(M19.Kol,0)+ISNULL(M20.Kol,0)+ISNULL(M21.Kol,0)+ISNULL(M22.Kol,0)+ISNULL(M23.Kol,0)),
											dbo.sgNumActiveMonths(3,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
											dbo.sgNumActiveMonths(6,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
											dbo.sgNumActiveMonths(12,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
											dbo.sgNumActiveMonths(24,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
											ISNULL(I0.Stock,0),
	                						ISNULL(SofiaM.SofiaMax,0),Q.SofiaPC,DAY(GETDATE()),ISNULL(Q.MaxFaktKol,0)),
	   'CHISTA ZAIAVKA' = dbo.sgCalcOrder(0,0,@initialOrderBuffer,ISNULL(ObrabotkaM.ObrabotkaMin,0),Q.Quality,
											ISNULL(Active.LeadTimeInMonths,1),ISNULL(M0.Kol,0),
											(ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0)),
											(ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0)+ISNULL(M4.Kol,0)+ISNULL(M5.Kol,0)+ISNULL(M6.Kol,0)),
											(ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0)+ISNULL(M4.Kol,0)+ISNULL(M5.Kol,0)+ISNULL(M6.Kol,0)+ISNULL(M7.Kol,0)+ISNULL(M8.Kol,0)+ISNULL(M9.Kol,0)+ISNULL(M10.Kol,0)+ISNULL(M11.Kol,0)+ISNULL(M12.Kol,0)),
											(ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0)+ISNULL(M4.Kol,0)+ISNULL(M5.Kol,0)+ISNULL(M6.Kol,0)+ISNULL(M7.Kol,0)+ISNULL(M8.Kol,0)+ISNULL(M9.Kol,0)+ISNULL(M10.Kol,0)+ISNULL(M11.Kol,0)+ISNULL(M12.Kol,0)
	              	  						+ISNULL(M13.Kol,0)+ISNULL(M14.Kol,0)+ISNULL(M15.Kol,0)+ISNULL(M16.Kol,0)+ISNULL(M17.Kol,0)+ISNULL(M18.Kol,0)+ISNULL(M19.Kol,0)+ISNULL(M20.Kol,0)+ISNULL(M21.Kol,0)+ISNULL(M22.Kol,0)+ISNULL(M23.Kol,0)),
											dbo.sgNumActiveMonths(3,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
											dbo.sgNumActiveMonths(6,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
											dbo.sgNumActiveMonths(12,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
											dbo.sgNumActiveMonths(24,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
											ISNULL(I0.Stock,0),
	                						ISNULL(SofiaM.SofiaMax,0),Q.SofiaPC,DAY(GETDATE()),ISNULL(Q.MaxFaktKol,0)),
	   '9 S CHISTA ZAIAVKA' = dbo.sgCalcOrder(0,1,@initialOrderBuffer,ISNULL(ObrabotkaM.ObrabotkaMin,0),Q.Quality,
											ISNULL(Active.LeadTimeInMonths,1),ISNULL(M0.Kol,0),
											(ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0)),
											(ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0)+ISNULL(M4.Kol,0)+ISNULL(M5.Kol,0)+ISNULL(M6.Kol,0)),
											(ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0)+ISNULL(M4.Kol,0)+ISNULL(M5.Kol,0)+ISNULL(M6.Kol,0)+ISNULL(M7.Kol,0)+ISNULL(M8.Kol,0)+ISNULL(M9.Kol,0)+ISNULL(M10.Kol,0)+ISNULL(M11.Kol,0)+ISNULL(M12.Kol,0)),
											(ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0)+ISNULL(M4.Kol,0)+ISNULL(M5.Kol,0)+ISNULL(M6.Kol,0)+ISNULL(M7.Kol,0)+ISNULL(M8.Kol,0)+ISNULL(M9.Kol,0)+ISNULL(M10.Kol,0)+ISNULL(M11.Kol,0)+ISNULL(M12.Kol,0)
	              	  						+ISNULL(M13.Kol,0)+ISNULL(M14.Kol,0)+ISNULL(M15.Kol,0)+ISNULL(M16.Kol,0)+ISNULL(M17.Kol,0)+ISNULL(M18.Kol,0)+ISNULL(M19.Kol,0)+ISNULL(M20.Kol,0)+ISNULL(M21.Kol,0)+ISNULL(M22.Kol,0)+ISNULL(M23.Kol,0)),
											dbo.sgNumActiveMonths(3,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
											dbo.sgNumActiveMonths(6,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
											dbo.sgNumActiveMonths(12,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
											dbo.sgNumActiveMonths(24,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
											ISNULL(I0.Stock,0),
	                						ISNULL(SofiaM.SofiaMax,0),Q.SofiaPC,DAY(GETDATE()),ISNULL(Q.MaxFaktKol,0)),
	   --DEV SNIP LINE BELOW
	   ISNULL(CountClients3.ClientCount,0) AS 'Broi Klienti (3)', 
	   ISNULL(CountClientsThisYear.ClientCount,0) AS 'Broi Klienti (tazi godina)', 
       'Sredni Prodazhbi prez Aktiven Mesec(3)' = (ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0))/dbo.sgNumActiveMonths(3,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
       'Sredni Prodazhbi prez Aktiven Mesec(6)' = (ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0)+ISNULL(M4.Kol,0)+ISNULL(M5.Kol,0)+ISNULL(M6.Kol,0))/dbo.sgNumActiveMonths(6,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
	   'Sredni Prodazhbi prez Aktiven Mesec(12)' =(ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0)+ISNULL(M4.Kol,0)+ISNULL(M5.Kol,0)+ISNULL(M6.Kol,0)+ISNULL(M7.Kol,0)+ISNULL(M8.Kol,0)+ISNULL(M9.Kol,0)+ISNULL(M10.Kol,0)+ISNULL(M11.Kol,0)+ISNULL(M12.Kol,0))/dbo.sgNumActiveMonths(12,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
	   'Sredni Prodazhbi prez Aktiven Mesec(24)' =(ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0)+ISNULL(M4.Kol,0)+ISNULL(M5.Kol,0)+ISNULL(M6.Kol,0)+ISNULL(M7.Kol,0)+ISNULL(M8.Kol,0)+ISNULL(M9.Kol,0)+ISNULL(M10.Kol,0)+ISNULL(M11.Kol,0)+ISNULL(M12.Kol,0)
	              +ISNULL(M13.Kol,0)+ISNULL(M14.Kol,0)+ISNULL(M15.Kol,0)+ISNULL(M16.Kol,0)+ISNULL(M17.Kol,0)+ISNULL(M18.Kol,0)+ISNULL(M19.Kol,0)+ISNULL(M20.Kol,0)+ISNULL(M21.Kol,0)+ISNULL(M22.Kol,0)+ISNULL(M23.Kol,0))/dbo.sgNumActiveMonths(24,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
       'Aktivni Meseca(3)' = dbo.sgNumActiveMonths(3,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
       'Aktivni Meseca(6)' = dbo.sgNumActiveMonths(6,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
       'Aktivni Meseca(12)' = dbo.sgNumActiveMonths(12,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
       'Aktivni Meseca(24)' = dbo.sgNumActiveMonths(24,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
       ISNULL(M0.Kol,0) AS 'Prodazhbi Tozi Mesec', 
	   'Sredni Prodazhbi na Mesec(3)' = (ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0))/3,
       'Sredni Prodazhbi na Mesec(6)' = (ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0)+ISNULL(M4.Kol,0)+ISNULL(M5.Kol,0)+ISNULL(M6.Kol,0))/6,
	   'Sredni Prodazhbi na Mesec(12)' =(ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0)+ISNULL(M4.Kol,0)+ISNULL(M5.Kol,0)+ISNULL(M6.Kol,0)+ISNULL(M7.Kol,0)+ISNULL(M8.Kol,0)+ISNULL(M9.Kol,0)+ISNULL(M10.Kol,0)+ISNULL(M11.Kol,0)+ISNULL(M12.Kol,0))/12,
	   'Sredni Prodazhbi na Mesec(24)' =(ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0)+ISNULL(M4.Kol,0)+ISNULL(M5.Kol,0)+ISNULL(M6.Kol,0)+ISNULL(M7.Kol,0)+ISNULL(M8.Kol,0)+ISNULL(M9.Kol,0)+ISNULL(M10.Kol,0)+ISNULL(M11.Kol,0)+ISNULL(M12.Kol,0)
	              +ISNULL(M13.Kol,0)+ISNULL(M14.Kol,0)+ISNULL(M15.Kol,0)+ISNULL(M16.Kol,0)+ISNULL(M17.Kol,0)+ISNULL(M18.Kol,0)+ISNULL(M19.Kol,0)+ISNULL(M20.Kol,0)+ISNULL(M21.Kol,0)+ISNULL(M22.Kol,0)+ISNULL(M23.Kol,0)+ISNULL(M24.Kol,0))/24,
       ISNULL(I25.Stock,0) AS I25,
       ISNULL(I24.Stock,0) AS I24,
       ISNULL(I23.Stock,0) AS I23,
       ISNULL(I22.Stock,0) AS I22,
       ISNULL(I21.Stock,0) AS I21,
       ISNULL(I20.Stock,0) AS I20,
       ISNULL(I19.Stock,0) AS I19,
       ISNULL(I18.Stock,0) AS I18,
       ISNULL(I17.Stock,0) AS I17,
       ISNULL(I16.Stock,0) AS I16,         
       ISNULL(I15.Stock,0) AS I15,
       ISNULL(I14.Stock,0) AS I14,
       ISNULL(I13.Stock,0) AS I13,
       ISNULL(I12.Stock,0) AS I12,
       ISNULL(I11.Stock,0) AS I11,
       ISNULL(I10.Stock,0) AS I10,
       ISNULL(I9.Stock,0) AS I9,
       ISNULL(I8.Stock,0) AS I8,
       ISNULL(I7.Stock,0) AS I7,
       ISNULL(I6.Stock,0) AS I6,
       ISNULL(I5.Stock,0) AS I5,
       ISNULL(I4.Stock,0) AS I4,
       ISNULL(I3.Stock,0) AS I3,
       ISNULL(I2.Stock,0) AS I2,
	   ISNULL(I1.Stock,0) AS I1,
	   ISNULL(I0.Stock,0) AS 'Inventar Vsichki Obekti Sega',
	   --DEV SNIP HERE 
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
	   ISNULL(Kol2014.Kol,0) AS '2014',
	   --DEV SNIP To here
       DnevnaZagubaOtZakusnenieBGN = dbo.sgDailyOrderDelayCost((ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0))/dbo.sgNumActiveMonths(3,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
													ISNULL(Q.MaxFaktKol,0),Active.LeadTimeInMonths,ISNULL(I0.Stock,0),ISNULL(Q.ltmRevenue,0),ISNULL(Q.ltmGP,0),ISNULL(Q.ltmKol,0),ISNULL(Q.ltmCOGS,0),Active.PurchasePriceBGN),
	   DailyCapital = CAST(0 AS NUMERIC(12,6)),
	   0 AS Iteration,
	   DayToday = DAY(GETDATE()),
	   ISNULL(Q.ltmRevenue,0) AS 'ltm Revenue',
	   ISNULL(Q.ltmGP,0) AS 'ltm GP',
	   ISNULL(Q.MaxFaktKol,0) AS 'MaxFaktKol',
	   Q.SofiaPC AS 'SofiaPC'
INTO #sgAdjPurchaseReport
FROM
#sgRelevantSMC Active
LEFT JOIN
(SELECT MinPrices.GroupSMCKod,MIN(PurchasePriceBGN) AS MinPrice 
FROM
(SELECT Grupa.GrupaSMC AS GroupSMCKod, Linked.CenaO1 AS PurchasePriceBGN
 FROM 
     (SELECT K.Kod1 AS GrupaSMC,K.Ime1 AS GrupaIme,Cat.Kod2 AS CatalozhenNomer 
     FROM
        T2014.dbo.Klas_SMC K
        FULL OUTER JOIN Klas_SMC_CatalogNo Cat ON Cat.SMCID = K.ID
        LEFT JOIN T2012.dbo.sgQualityScores QS ON QS.SMCId = K.ID
        WHERE K.Kod1 LIKE @SMCKod AND K.Aktivno = 1 AND QS.Quality IS NOT NULL) Grupa
    FULL OUTER JOIN
    (SELECT K.ID AS ID,K.Kod1 AS SvurzanSMC,K.Ime1 AS SvurzanIme,Cat.Kod2 AS CatalozhenNomer,K.CenaO1 AS CenaO1, ISNULL(LT.LeadTime,1) AS LeadTimeInMonths 
        FROM
            T2014.dbo.Klas_SMC K
            FULL OUTER JOIN Klas_SMC_CatalogNo Cat ON Cat.SMCID = K.ID
            LEFT JOIN T2012.dbo.sgLeadTimes LT ON LT.Grupa = K.Grupi
			LEFT JOIN T2012.dbo.sgQualityScores QS ON QS.SMCId = K.ID
            WHERE K.Kod1 NOT LIKE @SMCKod AND K.Aktivno = 1 AND QS.Quality IS NOT NULL) Linked ON Linked.SvurzanSMC = Grupa.CatalozhenNomer
    WHERE Grupa.GrupaSMC IS NOT NULL AND Linked.SvurzanSMC IS NOT NULL
    GROUP BY Grupa.GrupaSMC, Grupa.GrupaIme, Grupa.CatalozhenNomer,Linked.SvurzanSMC,Linked.ID,Linked.SvurzanIme,Linked.CenaO1,Linked.LeadTimeInMonths
UNION ALL
SELECT K.Kod1 AS GroupSMCKod, K.CenaO1 AS PurchasePriceBGN
            FROM T2014.dbo.[Klas_SMC] K
            LEFT JOIN T2012.dbo.sgLeadTimes LT ON LT.Grupa = K.Grupi
			LEFT JOIN T2012.dbo.sgQualityScores QS ON QS.SMCId = K.ID
            WHERE K.Kod1 LIKE @SMCKod AND K.Aktivno = 1 AND QS.Quality IS NOT NULL) MinPrices
GROUP BY MinPrices.GroupSMCKod) Cheapest ON Cheapest.GroupSMCKod = Active.GroupSMCKod
LEFT JOIN
(SELECT QS.SMCId AS SMCId,ROUND(QS.Quality,0) AS Quality, QS.Revenue AS ltmRevenue, QS.GP AS ltmGP, QS.Kol AS ltmKol, QS.COGS AS ltmCOGS,QS.MaxFaktKol AS MaxFaktKol,
  	ISNULL(QS.SofiaKol,0) / ISNULL(QS.Kol,1) AS SofiaPC,
    ISNULL(QS.VarnaKol,0) / ISNULL(QS.Kol,1) AS VarnaPC,
    ISNULL(QS.RuseKol,0) / ISNULL(QS.Kol,1) AS RusePC,
    ISNULL(QS.VTKol,0) / ISNULL(QS.Kol,1) AS VTPC
	FROM T2012.dbo.sgQualityScores QS) Q ON Q.SMCId = Active.SMCRaw	
LEFT JOIN
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())+0) M0 ON M0.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-1) M1 ON M1.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-2) M2 ON M2.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-3) M3 ON M3.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-4) M4 ON M4.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-5) M5 ON M5.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-6) M6 ON M6.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-7) M7 ON M7.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-8) M8 ON M8.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-9) M9 ON M9.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-10) M10 ON M10.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-11) M11 ON M11.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-12) M12 ON M12.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-13) M13 ON M13.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-14) M14 ON M14.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-15) M15 ON M15.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-16) M16 ON M16.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-17) M17 ON M17.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-18) M18 ON M18.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-19) M19 ON M19.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-20) M20 ON M20.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-21) M21 ON M21.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-22) M22 ON M22.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-23) M23 ON M23.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-24) M24 ON M24.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-25) M25 ON M25.SMCKod = Active.SMCRaw
LEFT JOIN
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())+1) Latest ON Latest.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())+1) I0 ON Active.SMCRaw = I0.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())+0) I1 ON Active.SMCRaw = I1.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-1) I2 ON Active.SMCRaw = I2.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-2) I3 ON Active.SMCRaw = I3.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-3) I4 ON Active.SMCRaw = I4.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-4) I5 ON Active.SMCRaw = I5.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-5) I6 ON Active.SMCRaw = I6.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-6) I7 ON Active.SMCRaw = I7.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-7) I8 ON Active.SMCRaw = I8.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-8) I9 ON Active.SMCRaw = I9.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-9) I10 ON Active.SMCRaw = I10.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-10) I11 ON Active.SMCRaw = I11.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-11) I12 ON Active.SMCRaw = I12.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-12) I13 ON Active.SMCRaw = I13.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-13) I14 ON Active.SMCRaw = I14.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-14) I15 ON Active.SMCRaw = I15.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-15) I16 ON Active.SMCRaw = I16.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-16) I17 ON Active.SMCRaw = I17.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-17) I18 ON Active.SMCRaw = I18.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-18) I19 ON Active.SMCRaw = I19.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-19) I20 ON Active.SMCRaw = I20.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-20) I21 ON Active.SMCRaw = I21.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-21) I22 ON Active.SMCRaw = I22.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-22) I23 ON Active.SMCRaw = I23.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-23) I24 ON Active.SMCRaw = I24.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-24) I25 ON Active.SMCRaw = I25.SMCKod
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
      Z.MOL  = 240  --Obrabotka
) ObrabotkaM ON Active.SMCRaw = ObrabotkaM.SMCKod
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
) SofiaM ON Active.SMCRaw = SofiaM.SMCKod
--DEV SNIP FROM HERE DOWN
LEFT JOIN
(
	SELECT K.ID AS SMCKod,K.Ime1 AS SMCIme,COUNT(DISTINCT F.Klient) AS ClientCount
	FROM T2014.dbo.Fakt F
	INNER JOIN T2014.dbo.FaktN FN ON F.ID = FN.FaktId
	INNER JOIN T2014.dbo.Klas_SMC K ON K.ID = FN.VidSMC
	WHERE F.Data >= DATEADD(month, -3, GETDATE()) 
	AND F.Data < GETDATE() AND F.Podelenie1 <> 21 AND F.Podelenie1 <> 4
	GROUP BY K.Id,K.Ime1) CountClients3 ON Active.SMCRaw = CountClients3.SMCKod
LEFT JOIN
(
	SELECT K.ID AS SMCKod,K.Ime1 AS SMCIme,COUNT(DISTINCT F.Klient) AS ClientCount
	FROM T2014.dbo.Fakt F
	INNER JOIN T2014.dbo.FaktN FN ON F.ID = FN.FaktId
	INNER JOIN T2014.dbo.Klas_SMC K ON K.ID = FN.VidSMC
	WHERE F.Podelenie1 <> 21 AND F.Podelenie1 <> 4
	GROUP BY K.Id,K.Ime1) CountClientsThisYear ON Active.SMCRaw = CountClientsThisYear.SMCKod
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
) ByalaM ON ByalaM.SMCKod = Active.SMCRaw
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
) RuseM ON Active.SMCRaw= RuseM.SMCKod
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
) VarnaM ON Active.SMCRaw = VarnaM.SMCKod
LEFT JOIN
(SELECT SUM(SD.QTY) AS SofiaInv, K.ID AS SMCKod, K.Ime1 as SMCIme
FROM dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
WHERE SD.Store IN (
 SELECT  Id = 8 --Sofia
 UNION
 SELECT  Id 
 FROM    dbo.MOL_Nashi 
 WHERE   ID_Podchinenie = 8
)
GROUP BY SD.Iv, K.ID, K.Ime1 HAVING SUM(SD.QTY)>=0) SofiaInv ON Active.SMCRaw = SofiaInv.SMCKod
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
GROUP BY SD.Iv, K.ID, K.Ime1 HAVING SUM(SD.QTY)>=0) ByalaInv ON Active.SMCRaw = ByalaInv.SMCKod
LEFT JOIN
(SELECT SUM(SD.QTY) AS VTInv, K.ID AS SMCKod, K.Ime1 as SMCIme
FROM dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
WHERE SD.Store IN (
 SELECT  Id = 278 --Veliko Turnovo
 UNION
 SELECT  Id 
 FROM    dbo.MOL_Nashi 
 WHERE   ID_Podchinenie = 278
)
GROUP BY SD.Iv, K.ID, K.Ime1 HAVING SUM(SD.QTY)>=0) VTInv ON Active.SMCRaw = VTInv.SMCKod
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
GROUP BY SD.Iv, K.ID, K.Ime1 HAVING SUM(SD.QTY)>=0) RuseInv ON Active.SMCRaw = RuseInv.SMCKod
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
GROUP BY SD.Iv, K.ID, K.Ime1 HAVING SUM(SD.QTY)>=0) VarnaInv ON Active.SMCRaw = VarnaInv.SMCKod   
LEFT JOIN
(SELECT K.ID AS SMCKod, K.Ime1 AS SMCIme,SUM(FN.Kol) AS Kol
FROM dbo.Fakt F
 INNER JOIN dbo.FaktN FN ON F.ID = FN.FaktId
 INNER JOIN dbo.Klas_SMC K ON K.ID = FN.VidSMC
 WHERE F.Data >= DATEADD(month, -3, GETDATE()) AND F.Data < GETDATE() AND F.Podelenie1 <> 21 AND F.Podelenie1 <> 4
 GROUP BY K.ID,K.Ime1) Recent3MonthKol ON Active.SMCRaw = Recent3MonthKol.SMCKod
LEFT JOIN
(
SELECT K.ID AS SMCKod, K.Ime1 AS SMCIme,SUM(FN.Kol) AS Kol
FROM dbo.Fakt F
 INNER JOIN dbo.FaktN FN ON F.ID = FN.FaktId
 INNER JOIN dbo.Klas_SMC K ON K.ID = FN.VidSMC
 WHERE F.Data >= DATEADD(month, -6, GETDATE()) AND F.Data < DATEADD(month, -3, GETDATE()) AND F.Podelenie1 <> 21 AND F.Podelenie1 <> 4
 GROUP BY K.ID,K.Ime1) Prior3MonthKol ON Active.SMCRaw = Prior3MonthKol.SMCKod
LEFT JOIN
(
SELECT K.ID AS SMCKod, K.Ime1 AS SMCIme,SUM(FN.Kol) AS Kol
FROM T2013.dbo.Fakt F
 INNER JOIN T2013.dbo.FaktN FN ON F.ID = FN.FaktId
 INNER JOIN T2013.dbo.Klas_SMC K ON K.ID = FN.VidSMC
 WHERE F.Data >= '20130101' AND F.Data < '20140101' AND F.Podelenie1 <> 21 AND F.Podelenie1 <> 4
 GROUP BY K.ID,K.Ime1) Kol2013 ON Active.SMCRaw = Kol2013.SMCKod
LEFT JOIN
(
SELECT K.ID AS SMCKod, K.Ime1 AS SMCIme,SUM(FN.Kol) AS Kol
FROM T2014.dbo.Fakt F
 INNER JOIN T2014.dbo.FaktN FN ON F.ID = FN.FaktId
 INNER JOIN T2014.dbo.Klas_SMC K ON K.ID = FN.VidSMC
 WHERE F.Podelenie1 <> 21 AND F.Podelenie1 <> 4
 GROUP BY K.ID,K.Ime1) Kol2014 ON Active.SMCRaw = Kol2014.SMCKod;
--DEV SNIP TO HERE	   
--ORDER BY Active.GroupSMCKod,Active.LinkedSMCKod;
/*
 * We only want to know about the hole cost for things the computer would order
 * So if CHISTA ZAIAVKA has zeros in it, we set the hole cost to zero
 */
UPDATE #sgAdjPurchaseReport
SET [DnevnaZagubaOtZakusnenieBGN] = CASE [CHISTA ZAIAVKA]
                     					WHEN 0 THEN 0
                     					ELSE [DnevnaZagubaOtZakusnenieBGN]
                  						END;
/*
 * If we are adjusting the order to get the right shipping, we iterate using Newton Raphson
 */
IF @targetOrderValue <> 0
BEGIN
	DECLARE @currOrderValue Real, @newOrderValue Real, @currentBuffer Real,@newBuffer Real,@iteration Integer, @firstOrderValue Real;
	DECLARE @deltaOrderValue Real, @deltaBuffer Real;
	SET @iteration = 0;
	SET @currentBuffer = @initialOrderBuffer;
	SELECT @firstOrderValue = SUM([Posl. Dost. Cena bez DDS v lv]*[CHISTA ZAIAVKA]) FROM #sgAdjPurchaseReport Report WHERE Report.LinkedSMCKod IS NULL; 
	SET @currOrderValue = @firstOrderValue;
	/*
	 * For the first iteration we expand the buffer by a gentle 5%
	 */
	SET @newBuffer = ((@currentBuffer+1) * 1.05)-1;
	UPDATE #sgAdjPurchaseReport
	SET [CHISTA ZAIAVKA] = dbo.sgCalcOrder(0,0,@newBuffer,[Komplekt k-vo],[Kachestvo],[Meseci za Dostavka],[Prodazhbi Tozi Mesec],
			                               [Sredni Prodazhbi na Mesec(3)]*3,
										   [Sredni Prodazhbi na Mesec(6)]*6,
										   [Sredni Prodazhbi na Mesec(12)]*12,
										   [Sredni Prodazhbi na Mesec(24)]*24,
										   [Aktivni Meseca(3)],
										   [Aktivni Meseca(6)],
										   [Aktivni Meseca(12)],
										   [Aktivni Meseca(24)],
										   [Inventar Vsichki Obekti],
										   SofiaMax,SofiaPC,DayToday,MaxFaktKol);
	SELECT @newOrderValue = SUM([Posl. Dost. Cena bez DDS v lv]*[CHISTA ZAIAVKA]) FROM #sgAdjPurchaseReport Report WHERE Report.LinkedSMCKod IS NULL;
	SET @deltaOrderValue = @newOrderValue - @currOrderValue;
	SET @deltaBuffer = @newBuffer - @currentBuffer;
	SET @currOrderValue = @newOrderValue;
	SET @currentBuffer = @newBuffer;
	WHILE   (@currOrderValue > @targetOrderValue * 1.1
      	    OR @currOrderValue < @targetOrderValue * 0.9)
           AND (@iteration < 10)
	BEGIN
		SET @newBuffer = @currentBuffer - (@currOrderValue - @targetOrderValue) / (@deltaOrderValue / @deltaBuffer)
		UPDATE #sgAdjPurchaseReport
	    SET [CHISTA ZAIAVKA] = dbo.sgCalcOrder(0,0,@newBuffer,[Komplekt k-vo],[Kachestvo],[Meseci za Dostavka],[Prodazhbi Tozi Mesec],
			                               [Sredni Prodazhbi na Mesec(3)]*3,
										   [Sredni Prodazhbi na Mesec(6)]*6,
										   [Sredni Prodazhbi na Mesec(12)]*12,
										   [Sredni Prodazhbi na Mesec(24)]*24,
										   [Aktivni Meseca(3)],
										   [Aktivni Meseca(6)],
										   [Aktivni Meseca(12)],
										   [Aktivni Meseca(24)],
										   [Inventar Vsichki Obekti],
										   SofiaMax,SofiaPC,DayToday,MaxFaktKol);
        UPDATE #sgAdjPurchaseReport
   		SET DailyCapital = CAST( ((@currentBuffer - @initialOrderBuffer)*[Meseci za Dostavka]*(@currOrderValue - @firstOrderValue)*0.1/365) AS numeric(12,6));
        UPDATE #sgAdjPurchaseReport
		SET Buffer = @newBuffer;
   		SELECT @newOrderValue = SUM([Posl. Dost. Cena bez DDS v lv]*[CHISTA ZAIAVKA]) FROM #sgAdjPurchaseReport Report WHERE Report.LinkedSMCKod IS NULL;
   		SET @deltaOrderValue = @newOrderValue - @currOrderValue;
   		SET @deltaBuffer = @newBuffer - @currentBuffer;
   		SET @currOrderValue = @newOrderValue;
   		SET @currentBuffer = @newBuffer;
   		SET @iteration = @iteration + 1;
        UPDATE #sgAdjPurchaseReport
   		SET [Iteration] = @iteration;
	END
	/*
	 * Now check if iterating has gotten us closer to where we want - if not, go back to the first order
	 */
	IF (abs(@currOrderValue - @targetOrderValue) > abs(@firstOrderValue - @targetOrderValue))
	BEGIN
		UPDATE #sgAdjPurchaseReport
		SET [CHISTA ZAIAVKA] = dbo.sgCalcOrder(0,0,@initialOrderBuffer,[Komplekt k-vo],[Kachestvo],[Meseci za Dostavka],[Prodazhbi Tozi Mesec],
			                               [Sredni Prodazhbi na Mesec(3)]*3,
										   [Sredni Prodazhbi na Mesec(6)]*6,
										   [Sredni Prodazhbi na Mesec(12)]*12,
										   [Sredni Prodazhbi na Mesec(24)]*24,
										   [Aktivni Meseca(3)],
										   [Aktivni Meseca(6)],
										   [Aktivni Meseca(12)],
										   [Aktivni Meseca(24)],
										   [Inventar Vsichki Obekti],
										   SofiaMax,SofiaPC,DayToday,MaxFaktKol);
		UPDATE #sgAdjPurchaseReport
   		SET DailyCapital = 0;
        UPDATE #sgAdjPurchaseReport
		SET Buffer = @initialOrderBuffer;
	END	
END
IF @bLog = 1
BEGIN
    DECLARE @orderValue Real;
    SELECT @orderValue = SUM([Posl. Dost. Cena bez DDS v lv]*[CHISTA ZAIAVKA]) FROM #sgAdjPurchaseReport Report WHERE Report.LinkedSMCKod IS NULL
	INSERT INTO T2012.dbo.sgScriptLog
	SELECT GetDate() AS Time, 'Purchase Report' AS ScriptName, @versionNum AS Version,USER_NAME() AS UserName,DATEDIFF(s,@startTime,getdate()),@SMCKod,@initialOrderBuffer,@targetOrderValue,@orderValue,NULL
END
--SELECT SUM([Posl. Dost. Cena bez DDS v lv]*[CHISTA ZAIAVKA]) FROM #sgAdjPurchaseReport;
--SELECT SUM(DnevnaZagubaOtZakusnenieBGN) FROM #sgAdjPurchaseReport;
SELECT * FROM #sgAdjPurchaseReport Report 

--SELECT COUNT(*) FROM #sgAdjPurchaseReport Report WHERE Proveri = 1
--SELECT * FROM #sgAdjPurchaseReport Report WHERE SofiaMax = 0 AND Kachestvo IS NOT NULL AND [Posl. Dost. Cena bez DDS v lv] < [Nai-evtina Cena]  --WHERE Proveri = 1

--exec sp_who2
--SELECT COUNT(*) FROM #sgAdjPurchaseReport WHERE SofiaMax = 0 AND [9 S CHISTA ZAIAVKA] > 0 AND [9 S CHISTA ZAIAVKA] <> 999999;
--SELECT COUNT(*) FROM #sgAdjPurchaseReport WHERE [9 S CHISTA ZAIAVKA] < 0;
	
