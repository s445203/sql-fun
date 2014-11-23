/*
 * OPISANIE:  Samo go pusni!  Ne pipai Nishto!
 *
 *  Pokazva koi SMCta triabva sa se premestiat of Sofia do obektite.
 *  Kak?
 *  Purvo obezpechava Sofia za 21 dni.  Ako sled tova ima dostatucnho
 *  i SMCto e dostatuchno oborotno za da triabva da go ima v nalichnost po obektite,
 *  gleda dali go ima i go razpredelia.
 * 
 *  Kogato smiatame kolko ima v Sofia, sklad obrabotka ne se gleda.
 */
/*
 * VERSION: 1
 *
 * Release History:
 * VERSION 1: 30.09.2014 Initial Release
 */
/*
 * All of the stores have the goods-in-travel store added to them as there is
 * no easy way to know to which store goods-in-travel are travelling to.
 * This allows this script to be re-run as soon as goods go into mezhdinen sklad rather
 * than when they enter the destination store inventory, which is about 2 days later.
 * However, it artifically inflates the mezhdinen sklad as it is added to each store inventory.
 */
IF NOT OBJECT_ID('tempdb..#sgRazpredelenieReport') IS NULL DROP TABLE #sgRazpredelenieReport;
DECLARE @proCentOtLeadTimeZaSofia Real, @maxKachestvoZaRazpredelenie INT, @dniObespechenieZaObekt Real;
SET @proCentOtLeadTimeZaSofia = 0.5;
SET @dniObespechenieZaObekt = 3;
SET @maxKachestvoZaRazpredelenie = 6000;  /* Ekvivalentno na BGN300k sklad na edin obekt */
SELECT Active.GroupSMCKod AS SMCKod, 
       Active.GroupSMCIme AS SMCIme,
       Active.PurchasePriceBGN AS 'Posl. Dost. Cena',
       ISNULL(ObrabotkaM.ObrabotkaMin,0) AS 'Komplekt k-vo',
       ISNULL(QualityData.Quality,99999) AS Quality,
		ROUND(@dniObespechenieZaObekt * ISNULL(QualityData.AnnualKol,0)/(52*5),0) AS 'Prodazhbi prez Obezpechen Srok - Obekt',
		ROUND(ISNULL(Active.LeadTimeInMonths,0) * @proCentOtLeadTimeZaSofia * ISNULL(QualityData.AnnualKol,0)/12,0) AS 'Prodazhbi v Sofia prez garantiran srok',
		ISNULL(QualityData.MaxFaktKol,0) AS MaxFaktKol,
       ISNULL(SofiaInv.SofiaInv,0) AS 'SofiaInv',
	   ISNULL(ObrabotkaInv.ObrabotkaInv,0) AS 'ObrabotkaInv',
	   ISNULL(VarnaInv.VarnaInv,0) AS 'VarnaInv',
	   ISNULL(RuseInv.RuseInv,0) AS 'RuseInv',
	   ISNULL(ByalaInv.ByalaInv,0) AS 'ByalaInv',
	   SofiaToByala = dbo.sgCalcMove(1,4,ISNULL(ObrabotkaM.ObrabotkaMin,0),ISNULL(QualityData.Quality,99999),
						ROUND(@dniObespechenieZaObekt * ISNULL(QualityData.AnnualKol,0)/(52*5),0),
						ROUND(Active.LeadTimeInMonths * @proCentOtLeadTimeZaSofia * ISNULL(QualityData.AnnualKol,0)/12,0),
						ISNULL(QualityData.MaxFaktKol,0),
						@maxKachestvoZaRazpredelenie,
						ISNULL(SofiaInv.SofiaInv,0) + ISNULL(ObrabotkaInv.ObrabotkaInv,0),
	   					ISNULL(VarnaInv.VarnaInv,0),
	   					ISNULL(RuseInv.RuseInv,0),
	   					ISNULL(ByalaInv.ByalaInv,0),
						ISNULL(VTInv.VTInv,0),ISNULL(ObrabotkaInv.ObrabotkaInv,0)),
	   --ByalaToSofia = dbo.sgCalcMove(4,1,ISNULL(QualityData.Quality,99999),
		--				ISNULL(QualityData.DaySales3,0),ISNULL(QualityData.DaySales21,0),ISNULL(QualityData.MaxFaktKol,0),
		--				3300,
		--				ISNULL(SofiaInv.SofiaInv,0),
	   	--				ISNULL(VarnaInv.VarnaInv,0),
	   	--				ISNULL(RuseInv.RuseInv,0),
	   	--				ISNULL(ByalaInv.ByalaInv,0),
	    --              ISNULL(VTInv.VTInv,0),ISNULL(ObrabotkaInv.ObrabotkaInv,0)),
	   SofiaToVarna = dbo.sgCalcMove(1,2,ISNULL(ObrabotkaM.ObrabotkaMin,0),ISNULL(QualityData.Quality,99999),
						ROUND(@dniObespechenieZaObekt * ISNULL(QualityData.AnnualKol,0)/(52*5),0),
						ROUND(Active.LeadTimeInMonths * @proCentOtLeadTimeZaSofia * ISNULL(QualityData.AnnualKol,0)/12,0),
						ISNULL(QualityData.MaxFaktKol,0),
						@maxKachestvoZaRazpredelenie,
						ISNULL(SofiaInv.SofiaInv,0)+ ISNULL(ObrabotkaInv.ObrabotkaInv,0),
	   					ISNULL(VarnaInv.VarnaInv,0),
	   					ISNULL(RuseInv.RuseInv,0),
	   					ISNULL(ByalaInv.ByalaInv,0),
	                    ISNULL(VTInv.VTInv,0),ISNULL(ObrabotkaInv.ObrabotkaInv,0)),
	   SofiaToRuse = dbo.sgCalcMove(1,3,ISNULL(ObrabotkaM.ObrabotkaMin,0),ISNULL(QualityData.Quality,99999),
						ROUND(@dniObespechenieZaObekt * ISNULL(QualityData.AnnualKol,0)/(52*5),0),
						ROUND(Active.LeadTimeInMonths * @proCentOtLeadTimeZaSofia * ISNULL(QualityData.AnnualKol,0)/12,0),
						ISNULL(QualityData.MaxFaktKol,0),
						@maxKachestvoZaRazpredelenie,
						ISNULL(SofiaInv.SofiaInv,0)+ ISNULL(ObrabotkaInv.ObrabotkaInv,0),
	   					ISNULL(VarnaInv.VarnaInv,0),
	   					ISNULL(RuseInv.RuseInv,0),
	   					ISNULL(ByalaInv.ByalaInv,0),
					    ISNULL(VTInv.VTInv,0),ISNULL(ObrabotkaInv.ObrabotkaInv,0)),
	    SofiaToVT = dbo.sgCalcMove(1,5,ISNULL(ObrabotkaM.ObrabotkaMin,0),ISNULL(QualityData.Quality,99999),
						ROUND(@dniObespechenieZaObekt * ISNULL(QualityData.AnnualKol,0)/(52*5),0),
						ROUND(Active.LeadTimeInMonths * @proCentOtLeadTimeZaSofia * ISNULL(QualityData.AnnualKol,0)/12,0),
						ISNULL(QualityData.MaxFaktKol,0),
						@maxKachestvoZaRazpredelenie,
						ISNULL(SofiaInv.SofiaInv,0)+ ISNULL(ObrabotkaInv.ObrabotkaInv,0),
	   					ISNULL(VarnaInv.VarnaInv,0),
	   					ISNULL(RuseInv.RuseInv,0),
	   					ISNULL(ByalaInv.ByalaInv,0),
					    ISNULL(VTInv.VTInv,0),ISNULL(ObrabotkaInv.ObrabotkaInv,0)),
	   ISNULL(MezhdinenInv.Mezhdinen,0) AS MezhdinenInv,
	   Active.AddressWH AS SofiaLocation,
	   Active.ExtraInfo AS 'Extra Info'
INTO #sgRazpredelenieReport					
FROM
(SELECT K.Kod1 AS GroupSMCKod, K.Ime1 AS GroupSMCIme, K.ID AS SMCRaw,K.CenaO1 AS PurchasePriceBGN,Warehouse.Ime AS AddressWH, ExtraInfo.Note AS ExtraInfo,ISNULL(LT.LeadTime,0) AS LeadTimeInMonths
    FROM T2014.dbo.[Klas_SMC] K
    LEFT JOIN T2014.dbo.[Klas_SMC_ForeignNames] Warehouse ON Warehouse.SMCID = K.Id AND Warehouse.NomIme = 255
    LEFT JOIN T2014.dbo.[Klas_SMC_ExtraInfo] ExtraInfo ON ExtraInfo.SMCID = K.Id
    LEFT JOIN T2012.dbo.sgLeadTimes LT ON LT.Grupa = K.Grupi
    WHERE K.Aktivno = 1) Active
LEFT JOIN
(SELECT QS.SMCId AS SMCKod, QS.Kol AS AnnualKol, QS.MaxFaktKol AS MaxFaktKol, QS.Quality AS Quality 
FROM T2012.dbo.sgQualityScores QS) QualityData ON QualityData.SMCKod = Active.SMCRaw
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
	SELECT  Id = 242 --Mezhdinen
    UNION
	SELECT  Id 
	FROM    dbo.MOL_Nashi 
	WHERE   ID_Podchinenie = 239
)
GROUP BY SD.Iv, K.Id, K.Ime1 HAVING SUM(SD.QTY)>=0) ByalaInv ON Active.SMCRaw = ByalaInv.SMCKod
LEFT JOIN
(SELECT SUM(SD.QTY) AS RuseInv, K.ID AS SMCKod, K.Ime1 as SMCIme
FROM dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
WHERE SD.Store IN (
	SELECT  Id = 245 --Ruse
	UNION
	SELECT  Id = 242 --Mezhdinen
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
	SELECT  Id = 279 --Varna 2
	UNION
	SELECT  Id = 242 --Mezhdinen
    UNION
	SELECT  Id 
	FROM    dbo.MOL_Nashi 
	WHERE   ID_Podchinenie = 279
)
GROUP BY SD.Iv, K.ID, K.Ime1 HAVING SUM(SD.QTY)>=0) VarnaInv ON Active.SMCRaw = VarnaInv.SMCKod
LEFT JOIN
(SELECT SUM(SD.QTY) AS VTInv, K.ID AS SMCKod, K.Ime1 as SMCIme
FROM dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
WHERE SD.Store IN (
	SELECT  Id = 278 --Veliko Turnovo
	UNION
	SELECT  Id = 242 --Mezhdinen
    UNION
	SELECT  Id 
	FROM    dbo.MOL_Nashi 
	WHERE   ID_Podchinenie = 279
)
GROUP BY SD.Iv, K.ID, K.Ime1 HAVING SUM(SD.QTY)>=0) VTInv ON Active.SMCRaw = VTInv.SMCKod
LEFT JOIN
(
	SELECT SUM(SD.QTY) AS Mezhdinen, K.ID AS SMCKod, K.Ime1 as SMCIme
	FROM dbo.[ViewN Salda] SD
	INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
	WHERE SD.Store IN (
		SELECT  Id = 242 --Mezhdinen
		UNION
		SELECT  Id 
		FROM    dbo.MOL_Nashi 
		WHERE   ID_Podchinenie = 242) 
GROUP BY SD.Iv, K.Id,K.Kod1, K.Ime1 HAVING SUM(SD.QTY)>0) MezhdinenInv ON Active.SMCRaw = MezhdinenInv.SMCKod
LEFT JOIN
(
	SELECT SUM(SD.QTY) AS ObrabotkaInv, K.ID AS SMCKod, K.Ime1 as SMCIme
	FROM dbo.[ViewN Salda] SD
	INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
	WHERE SD.Store IN (
		SELECT  Id = 240 --Obrabotka
		UNION
		SELECT  Id 
		FROM    dbo.MOL_Nashi 
		WHERE   ID_Podchinenie = 240) 
GROUP BY SD.Iv, K.Id,K.Kod1, K.Ime1 HAVING SUM(SD.QTY)>0) ObrabotkaInv ON Active.SMCRaw = ObrabotkaInv.SMCKod
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
      Z.MOL  = 240 --Obrabotka
) ObrabotkaM ON Active.SMCRaw = ObrabotkaM.SMCKod
WHERE Quality < @maxKachestvoZaRazpredelenie
ORDER BY Quality

SELECT * FROM #sgRazpredelenieReport
WHERE (SofiaToByala > 0) OR (SofiaToRuse > 0) OR (SofiaToVarna > 0) OR (SofiaToVT > 0)