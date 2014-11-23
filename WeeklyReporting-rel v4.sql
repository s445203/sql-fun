/*
 * OPISANIE:  Tozi file e samo za Stephan Gueorguiev.  Molia ne pipaite
 *            nishto po nego.  Ako ste stignali do tuk i imate nuzhda ot neshto, pishete mi
 *            na stephan.g@cantab.net
 */
/*
 * VERSION: 4
 *
 * Release History:
 * VERSION 4: 8.11.2014 Added calculation of actual inventory hole cost
 */
IF NOT OBJECT_ID('tempdb..#sgRazpredelenieReport') IS NULL DROP TABLE #sgRazpredelenieReport;
DECLARE @proCentOtLeadTimeZaSofia Real, @maxKachestvoZaRazpredelenie INT, @dniObespechenieZaObekt Real;
SET @proCentOtLeadTimeZaSofia = 0.5;
SET @dniObespechenieZaObekt = 5;
SET @maxKachestvoZaRazpredelenie = 6000;  /* Ekvivalentno na BGN300k sklad na edin obekt */
SELECT Active.GroupSMCKod AS SMCKod, 
       Active.GroupSMCIme AS SMCIme,
       Active.PurchasePriceBGN AS 'Posl. Dost. Cena',
       ISNULL(ObrabotkaM.ObrabotkaMin,0) AS 'Komplekt k-vo',
       ISNULL(QualityData.Quality,99999) AS Quality,
	   ROUND((1-QualityData.SofiaPC) * @dniObespechenieZaObekt * ISNULL(QualityData.AnnualKol,0)/(52*5),0) AS 'Prodazhbi prez Obezpechen Srok - Obekt',
	   ROUND(QualityData.SofiaPC * dbo.sgMax(Active.LeadTimeInMonths,0.5,0) * @proCentOtLeadTimeZaSofia * ISNULL(QualityData.AnnualKol,0)/12,0) AS 'Prodazhbi v Sofia prez garantiran srok',
	   ISNULL(QualityData.MaxFaktKol,0) AS MaxFaktKol,
       ISNULL(SofiaInv.SofiaInv,0) AS 'SofiaInv',
	   ISNULL(VarnaInv.VarnaInv,0) AS 'VarnaInv',
	   ISNULL(RuseInv.RuseInv,0) AS 'RuseInv',
	   ISNULL(ByalaInv.ByalaInv,0) AS 'ByalaInv',
	   SofiaToByala = dbo.sgCalcMove(1,4,ISNULL(ObrabotkaM.ObrabotkaMin,0),ISNULL(QualityData.Quality,99999),
						ROUND((1-QualityData.SofiaPC) * @dniObespechenieZaObekt * ISNULL(QualityData.AnnualKol,0)/(52*5),0),
						ROUND(QualityData.SofiaPC * dbo.sgMax(Active.LeadTimeInMonths,0.5,0) * @proCentOtLeadTimeZaSofia * ISNULL(QualityData.AnnualKol,0)/12,0),
						ISNULL(QualityData.MaxFaktKol,0),
						@maxKachestvoZaRazpredelenie,
						ISNULL(SofiaInv.SofiaInv,0),
	   					ISNULL(VarnaInv.VarnaInv,0),
	   					ISNULL(RuseInv.RuseInv,0),
	   					ISNULL(ByalaInv.ByalaInv,0),
						ISNULL(VTInv.VTInv,0),1000000),
	   SofiaToVarna = dbo.sgCalcMove(1,2,ISNULL(ObrabotkaM.ObrabotkaMin,0),ISNULL(QualityData.Quality,99999),
						ROUND((1-QualityData.SofiaPC) * @dniObespechenieZaObekt * ISNULL(QualityData.AnnualKol,0)/(52*5),0),
						ROUND(QualityData.SofiaPC * dbo.sgMax(Active.LeadTimeInMonths,0.5,0) * @proCentOtLeadTimeZaSofia * ISNULL(QualityData.AnnualKol,0)/12,0),
						ISNULL(QualityData.MaxFaktKol,0),
						@maxKachestvoZaRazpredelenie,
						ISNULL(SofiaInv.SofiaInv,0),
	   					ISNULL(VarnaInv.VarnaInv,0),
	   					ISNULL(RuseInv.RuseInv,0),
	   					ISNULL(ByalaInv.ByalaInv,0),
	                    ISNULL(VTInv.VTInv,0),1000000),
	   SofiaToRuse = dbo.sgCalcMove(1,3,ISNULL(ObrabotkaM.ObrabotkaMin,0),ISNULL(QualityData.Quality,99999),
						ROUND((1-QualityData.SofiaPC) * @dniObespechenieZaObekt * ISNULL(QualityData.AnnualKol,0)/(52*5),0),
						ROUND(QualityData.SofiaPC * dbo.sgMax(Active.LeadTimeInMonths,0.5,0) * @proCentOtLeadTimeZaSofia * ISNULL(QualityData.AnnualKol,0)/12,0),
						ISNULL(QualityData.MaxFaktKol,0),
						@maxKachestvoZaRazpredelenie,
						ISNULL(SofiaInv.SofiaInv,0),
	   					ISNULL(VarnaInv.VarnaInv,0),
	   					ISNULL(RuseInv.RuseInv,0),
	   					ISNULL(ByalaInv.ByalaInv,0),
					    ISNULL(VTInv.VTInv,0),1000000),
	    SofiaToVT = dbo.sgCalcMove(1,5,ISNULL(ObrabotkaM.ObrabotkaMin,0),ISNULL(QualityData.Quality,99999),
						ROUND((1-QualityData.SofiaPC) * @dniObespechenieZaObekt * ISNULL(QualityData.AnnualKol,0)/(52*5),0),
						ROUND(QualityData.SofiaPC * dbo.sgMax(Active.LeadTimeInMonths,0.5,0) * @proCentOtLeadTimeZaSofia * ISNULL(QualityData.AnnualKol,0)/12,0),
						ISNULL(QualityData.MaxFaktKol,0),
						@maxKachestvoZaRazpredelenie,
						ISNULL(SofiaInv.SofiaInv,0),
	   					ISNULL(VarnaInv.VarnaInv,0),
	   					ISNULL(RuseInv.RuseInv,0),
	   					ISNULL(ByalaInv.ByalaInv,0),
					    ISNULL(VTInv.VTInv,0),1000000),
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
(SELECT QS.SMCId AS SMCKod, QS.Kol AS AnnualKol, QS.MaxFaktKol AS MaxFaktKol, QS.Quality AS Quality,
	 ISNULL(QS.SofiaKol,0) / ISNULL(QS.Kol,1) AS SofiaPC
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
SELECT  K.ID AS SMCKod
 ,K.Ime1 AS SMCIme
 ,M.Ime AS Mol
 ,MinZ AS ObrabotkaMin
 FROM dbo.Klas_SMC_Zapasi Z
 INNER JOIN dbo.MOL_Nashi M ON Z.MOL = M.ID
 INNER JOIN  dbo.Klas_SMC K ON Z.SMCID = K.ID
WHERE Z.Podelenie1 = 6 AND 
      Z.MOL  = 240 AND --Obrabotka
      K.Grupi = ISNULL(NULLIF(0, 0), K.Grupi)
) ObrabotkaM ON Active.SMCRaw = ObrabotkaM.SMCKod
WHERE Quality < @maxKachestvoZaRazpredelenie
ORDER BY Quality


SELECT Nuzhda.[Sredno Kachestvo na SMC s Nuzhda za poruchvane],
       Nuzhda.[Stoinost na cialata poruchka],
       Nuzhda.[Broi SMCta za poruchvane],
       Nuzhda.DnevnaZagubaOtZakusnenieBGN,
       NuzhdaChista.[Sredno Kachestvo na SMC s Nuzhda za poruchvane] AS 'Poruchka Chisto Sredno Kachestvo',
       NuzhdaChista.[Stoinost na cialata poruchka] AS 'Poruchka Chisto Stoinost na Cialata Poruchka',
       NuzhdaChista.[Broi SMCta za poruchvane] AS 'Poruchka Chisto Broi SMCta za poruchvane',
       Count9s.[Broi SMCta s Order 999999],
       0.5 AS Buffer,
       6000 AS KachestvoZaPoruchkaZaRazpredelenie,
       Izlishuk.[Sredno Kachestvo na izlishuka],
       -1*Izlishuk.[Stoinost na izlishuka] AS 'Stoinost na izlishuka',
       Izlishuk.[Broi SMCta s izlishuk],
       IzlishukChist.[Sredno Kachestvo na izlishuka] AS 'Izlishuk Chisto Sredno Kachestvo',
       -1*IzlishukChist.[Stoinost na izlishuka]  AS 'Izlishuk Chisto Stoinost',
       IzlishukChist.[Broi SMCta s izlishuk] AS 'Islizhuk Chisto Broi SMCta',
	   SofiaToByala.Kol AS 'Sofia To Byala',
	   SofiaToVarna.Kol AS 'Sofia To Varna',
	   SofiaToRuse.Kol AS 'Sofia To Ruse',
	   SofiaToVT.Kol AS 'Sofia To VT',
	   6000 AS MaxKachestvoZaRazpredelenie,
	   0.5 AS PCLeadTimeSofia,
	   5 AS DniObezpechenie,
       COGS.[COGS Sold Last Week],
       COGS2013.[COGS 2013], 0 AS OrdersMade,
	   Stock.Stock, DeadStock.Stock AS DeadStock,
	   COGS.GP, COGS2013.GP AS GP2013, 
	   COGS.SofiaRev, COGS.VarnaRev, COGS.RuseRev, COGS.VTRev, COGS.ByalaRev,
	   SofiaStock = ROUND(Stock.Stock - Varna.Stock - Ruse.Stock - VT.Stock - Byala.Stock,0), 
	   ROUND(Varna.Stock,0) AS VarnaStock, ROUND(Ruse.Stock,0) AS RuseStock, ROUND(VT.Stock,0) AS VTStock, ROUND(Byala.Stock,0) AS ByalaStock,
	   Sofia.Gamma AS SofiaGamma, Varna.Gamma AS VarnaGamma, Ruse.Gamma AS RuseGamma, VT.Gamma AS VTGamma, Byala.Gamma AS ByalaGamma,
	   COGS.SofiaGPPC AS SofiaGPPC,
	   COGS.VarnaGPPC AS VarnaGPPC, 
	   COGS.RuseGPPC AS RuseGPPC,
	   COGS.VTGPPC AS VTGPPC,
	   COGS.ByalaGPPC AS ByalaGPPC,
	   COGS.AllGPPC AS AllGPPC,
	   Nuzhda.DnevnaZagubaOtDupkaBGN
FROM
(SELECT 'Weekly Reporting' AS ID, ROUND(AVG(QS.Quality),0) AS 'Sredno Kachestvo na SMC s Nuzhda za poruchvane',
	   ROUND(SUM(ROUND(Orders.OrderQ,0) * K.CenaO1),0) AS 'Stoinost na cialata poruchka', COUNT(*) AS 'Broi SMCta za poruchvane',
	   ROUND(SUM(Orders.DnevnaZagubaOtZakusnenieBGN),0) AS DnevnaZagubaOtZakusnenieBGN,
	   ROUND(SUM(Orders.DnevnaZagubaOtDupkaBGN),0) AS DnevnaZagubaOtDupkaBGN
FROM T2012.dbo.sgQualityScores QS 
LEFT JOIN T2012.dbo.sgOrderNeed Orders ON QS.SMCId = Orders.SMCId
LEFT JOIN T2014.dbo.Klas_SMC K ON K.ID = QS.SMCID
LEFT JOIN T2014.dbo.Grupi_SMC G ON G.Code = K.Grupi
WHERE Orders.SMCId IS NOT NULL AND ROUND(Orders.OrderQ,0) > 0) Nuzhda
LEFT JOIN
(SELECT 'Weekly Reporting' AS ID, ROUND(AVG(QS.Quality),0) AS 'Sredno Kachestvo na SMC s Nuzhda za poruchvane',
	   ROUND(SUM(ROUND(Orders.OrderQ,0) * K.CenaO1),0) AS 'Stoinost na cialata poruchka', COUNT(*) AS 'Broi SMCta za poruchvane',ROUND(SUM(Orders.DnevnaZagubaOtZakusnenieBGN),0) AS DnevnaZagubaOtZakusnenieBGN
FROM T2012.dbo.sgQualityScores QS 
LEFT JOIN T2012.dbo.sgOrderNeed Orders ON QS.SMCId = Orders.SMCId
LEFT JOIN T2014.dbo.Klas_SMC K ON K.ID = QS.SMCID
LEFT JOIN T2014.dbo.Grupi_SMC G ON G.Code = K.Grupi
WHERE Orders.SMCId IS NOT NULL AND ROUND(Orders.ChistaZaiavka,0) > 0) NuzhdaChista ON NuzhdaChista.ID = Nuzhda.ID
LEFT JOIN
(SELECT 'Weekly Reporting' AS ID, ROUND(AVG(QS.Quality),0) AS 'Sredno Kachestvo na izlishuka',
	   ROUND(SUM(ROUND(Orders.OrderQ,0) * K.CenaO1),0) AS 'Stoinost na izlishuka', COUNT(*) AS 'Broi SMCta s izlishuk'
FROM T2012.dbo.sgQualityScores QS 
LEFT JOIN T2012.dbo.sgOrderNeed Orders ON QS.SMCId = Orders.SMCId
LEFT JOIN T2014.dbo.Klas_SMC K ON K.ID = QS.SMCID
LEFT JOIN T2014.dbo.Grupi_SMC G ON G.Code = K.Grupi
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
) SofiaM ON QS.SMCId = SofiaM.SMCKod
WHERE Orders.SMCId IS NOT NULL AND ROUND(Orders.OrderQ,0) < 0 AND SofiaM.SofiaMax = 999999) IzlishukChist ON IzlishukChist.ID = Nuzhda.ID
LEFT JOIN
(SELECT 'Weekly Reporting' AS ID,COUNT(*) AS 'Broi SMCta s Order 999999' FROM T2012.dbo.sgOrderNeed WHERE OrderQs9 = 999999) Count9s ON Count9S.ID = Nuzhda.ID
LEFT JOIN
(SELECT 'Weekly Reporting' AS ID, ROUND(AVG(QS.Quality),0) AS 'Sredno Kachestvo na izlishuka',
	   ROUND(SUM(ROUND(Orders.OrderQ,0) * K.CenaO1),0) AS 'Stoinost na izlishuka', COUNT(*) AS 'Broi SMCta s izlishuk'
FROM T2012.dbo.sgQualityScores QS 
LEFT JOIN T2012.dbo.sgOrderNeed Orders ON QS.SMCId = Orders.SMCId
LEFT JOIN T2014.dbo.Klas_SMC K ON K.ID = QS.SMCID
LEFT JOIN T2014.dbo.Grupi_SMC G ON G.Code = K.Grupi
WHERE Orders.SMCId IS NOT NULL AND ROUND(Orders.OrderQ,0) < 0) Izlishuk ON Nuzhda.ID = Izlishuk.ID
LEFT JOIN
(SELECT 'Weekly Reporting' AS ID,ROUND(SUM(IndividualSMC.COGS),0) AS 'COGS Sold Last Week',ROUND(SUM(IndividualSMC.GP),0) AS GP,
ROUND(SUM(IndividualSMC.SofiaRev),0) AS SofiaRev,
ROUND(SUM(IndividualSMC.VarnaRev),0) AS VarnaRev,
ROUND(SUM(IndividualSMC.RuseRev),0) AS RuseRev,
ROUND(SUM(IndividualSMC.VTRev),0) AS VTRev,
ROUND(SUM(IndividualSMC.ByalaRev),0) AS ByalaRev,
ROUND(SUM(IndividualSMC.SofiaCOGS),0) AS SofiaCOGS,
ROUND(SUM(IndividualSMC.VarnaCOGS),0) AS VarnaCOGS,
ROUND(SUM(IndividualSMC.RuseCOGS),0) AS RuseCOGS,
ROUND(SUM(IndividualSMC.VTCOGS),0) AS VTCOGS,
ROUND(SUM(IndividualSMC.ByalaCOGS),0) AS ByalaCOGS,
ROUND(SUM(IndividualSMC.SofiaGP),0) AS SofiaGP,
ROUND(SUM(IndividualSMC.VarnaGP),0) AS VarnaGP,
ROUND(SUM(IndividualSMC.RuseGP),0) AS RuseGP,
ROUND(SUM(IndividualSMC.VTGP),0) AS VTGP,
ROUND(SUM(IndividualSMC.ByalaGP),0) AS ByalaGP,
ROUND(100*SUM(IndividualSMC.SofiaGP) / SUM(IndividualSMC.SofiaRev),2) AS SofiaGPPC,
ROUND(100*SUM(IndividualSMC.VarnaGP) / SUM(IndividualSMC.VarnaRev),2) AS VarnaGPPC,
ROUND(100*SUM(IndividualSMC.RuseGP) / SUM(IndividualSMC.RuseRev),2) AS RuseGPPC,
ROUND(100*SUM(IndividualSMC.VTGP) / SUM(IndividualSMC.VTRev),2) AS VTGPPC,
ROUND(100*SUM(IndividualSMC.ByalaGP) / SUM(IndividualSMC.ByalaRev),2) AS ByalaGPPC,
ROUND(100*SUM(IndividualSMC.GP)/(SUM(IndividualSMC.COGS)+SUM(IndividualSMC.GP)),2) AS AllGPPC
FROM
(SELECT K.ID AS SMCId,K.Ime1,SUM(DtKt.Kol) AS Kol, 
        SUM(DtKt.ProdSt_K) AS Revenue, 
        SUM(CASE WHEN DtKt.Kt_MOLNashID = 8 OR MOL.ID_Podchinenie = 8 THEN DtKt.ProdSt_K ELSE 0 END) AS SofiaRev,
        SUM(CASE WHEN (DtKt.Kt_MOLNashID = 279 OR DtKt.Kt_MOLNashID = 215) THEN DtKt.ProdSt_K ELSE 0 END) AS VarnaRev,
        SUM(CASE WHEN DtKt.Kt_MOLNashID = 245 THEN DtKt.ProdSt_K ELSE 0 END) AS RuseRev, 
        SUM(CASE WHEN DtKt.Kt_MOLNashID = 239 THEN DtKt.ProdSt_K ELSE 0 END) AS ByalaRev,
        SUM(CASE WHEN DtKt.Kt_MOLNashID = 278 THEN DtKt.ProdSt_K ELSE 0 END) AS VTRev,
        SUM(CASE WHEN DtKt.Kt_MOLNashID = 8 OR MOL.ID_Podchinenie = 8 THEN DtKt.Suma ELSE 0 END) AS SofiaCOGS,
        SUM(CASE WHEN (DtKt.Kt_MOLNashID = 279 OR DtKt.Kt_MOLNashID = 215) THEN DtKt.Suma ELSE 0 END) AS VarnaCOGS,
        SUM(CASE WHEN DtKt.Kt_MOLNashID = 245 THEN DtKt.Suma ELSE 0 END) AS RuseCOGS, 
        SUM(CASE WHEN DtKt.Kt_MOLNashID = 239 THEN DtKt.Suma ELSE 0 END) AS ByalaCOGS,
        SUM(CASE WHEN DtKt.Kt_MOLNashID = 278 THEN DtKt.Suma ELSE 0 END) AS VTCOGS,
        SUM(CASE WHEN DtKt.Kt_MOLNashID = 8 OR MOL.ID_Podchinenie = 8 THEN DtKt.ProdSt_K - DtKt.Suma ELSE 0 END) AS SofiaGP,
        SUM(CASE WHEN (DtKt.Kt_MOLNashID = 279 OR DtKt.Kt_MOLNashID = 215) THEN DtKt.ProdSt_K - DtKt.Suma ELSE 0 END) AS VarnaGP,
        SUM(CASE WHEN DtKt.Kt_MOLNashID = 245 THEN DtKt.ProdSt_K - DtKt.Suma ELSE 0 END) AS RuseGP, 
        SUM(CASE WHEN DtKt.Kt_MOLNashID = 239 THEN DtKt.ProdSt_K - DtKt.Suma ELSE 0 END) AS ByalaGP,
        SUM(CASE WHEN DtKt.Kt_MOLNashID = 278 THEN DtKt.ProdSt_K - DtKt.Suma ELSE 0 END) AS VTGP, 
        SUM(DtKt.Suma) AS COGS, SUM(DtKt.ProdSt_K) - SUM(DtKt.Suma) AS GP
FROM T2014.dbo.[View ReportGenerator Dvig SourceDtKt] DtKt
INNER JOIN T2014.dbo.Klas_SMC K ON DtKt.Dt_SMCId = K.ID
INNER JOIN T2014.dbo.SmetkoPlan KtSP ON KtSP.ID = DtKt.Kt_SP_SmetkaId
INNER JOIN T2014.dbo.SmetkoPlan DtSp ON DtSP.ID = DtKt.Dt_SP_SmetkaId
INNER JOIN T2014.dbo.MOL_Nashi MOL ON MOL.ID = DtKt.Kt_MOLNashID
WHERE  ((DtSP.Smetka >= 700 AND DtSP.Smetka < 710) OR (DtSP.Smetka >= 7000 AND DtSP.Smetka < 7100)) AND K.Kod1 NOT LIKE '99000000%'
   AND ((KtSP.Smetka >= 300 AND KtSP.Smetka < 310) OR (KtSP.Smetka >= 3000 AND KtSP.Smetka < 3100)) 
   AND DtKt.Data >= DATEADD(DAY,-7,GETDATE()) AND DtKt.Data < GETDATE()
   AND DtKt.Podelenie1 <> 4 AND DtKt.Podelenie1 <> 21
GROUP BY K.ID,K.Ime1) IndividualSMC) COGS ON COGS.ID = Nuzhda.ID
LEFT JOIN
(SELECT 'Weekly Reporting' AS ID,ROUND(SUM(IndividualSMC.COGS),0) AS 'COGS 2013',ROUND(SUM(IndividualSMC.GP),0) AS GP
FROM
(SELECT K.ID AS SMCId,K.Ime1,SUM(DtKt.Kol) AS Kol, 
        SUM(DtKt.ProdSt_K) AS Revenue, SUM(DtKt.Suma) AS COGS, SUM(DtKt.ProdSt_K) - SUM(DtKt.Suma) AS GP
FROM T2013.dbo.[View ReportGenerator Dvig SourceDtKt] DtKt
INNER JOIN T2014.dbo.Klas_SMC K ON DtKt.Dt_SMCId = K.ID
INNER JOIN T2014.dbo.SmetkoPlan KtSP ON KtSP.ID = DtKt.Kt_SP_SmetkaId
INNER JOIN T2014.dbo.SmetkoPlan DtSp ON DtSP.ID = DtKt.Dt_SP_SmetkaId
WHERE  ((DtSP.Smetka >= 700 AND DtSP.Smetka < 710) OR (DtSP.Smetka >= 7000 AND DtSP.Smetka < 7100)) AND K.Kod1 NOT LIKE '99000000%'
   AND ((KtSP.Smetka >= 300 AND KtSP.Smetka < 310) OR (KtSP.Smetka >= 3000 AND KtSP.Smetka < 3100)) 
   AND DtKt.Data >= DATEADD(DAY,-53*7,GETDATE()) AND DtKt.Data < DATEADD(DAY,-52*7,GETDATE())
   AND DtKt.Podelenie1 <> 4 AND DtKt.Podelenie1 <> 21
GROUP BY K.ID,K.Ime1) IndividualSMC) COGS2013 ON COGS2013.ID = Nuzhda.ID
LEFT JOIN
(SELECT 'Weekly Reporting' AS ID, SUM(Active.OtchCena * Active.QTY) AS Stock, COUNT(*) AS Gamma FROM
(
SELECT SUM(SD.QTY) AS QTY, K.Kod1 AS Kod, K.Ime1 as Ime, ISNULL(Ceni.Cena,0) AS OtchCena
FROM dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
INNER JOIN T2014.dbo.Klas_SMC_Ceni Ceni ON Ceni.SMCId = K.ID AND Ceni.NomCena = 11
LEFT JOIN T2012.dbo.sgQualityScores QS ON QS.SMCId = K.ID
WHERE SD.Store IN (
	SELECT  Id 
	FROM    dbo.MOL_Nashi 
	WHERE   Podelenie1 = 6
) --AND SD.Period < 9 AND QS.SMCId IS NULL  --Flip on or off to get dead stock.
GROUP BY SD.Iv, K.Kod1, K.Ime1,Ceni.Cena HAVING SUM(SD.QTY)>0) Active) Stock ON Stock.ID = Nuzhda.ID
LEFT JOIN
(SELECT 'Weekly Reporting' AS ID, SUM(Active.OtchCena * Active.QTY) AS Stock FROM
(
SELECT SUM(SD.QTY) AS QTY, K.Kod1 AS Kod, K.Ime1 as Ime, ISNULL(Ceni.Cena,0) AS OtchCena
FROM dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
INNER JOIN T2014.dbo.Klas_SMC_Ceni Ceni ON Ceni.SMCId = K.ID AND Ceni.NomCena = 11
LEFT JOIN T2012.dbo.sgQualityScores QS ON QS.SMCId = K.ID
WHERE SD.Store IN (
	SELECT  Id 
	FROM    dbo.MOL_Nashi 
	WHERE   Podelenie1 = 6
) AND QS.SMCId IS NULL  --Flip on or off to get dead stock.
GROUP BY SD.Iv, K.Kod1, K.Ime1,Ceni.Cena HAVING SUM(SD.QTY)>0) Active) DeadStock ON DeadStock.ID = Nuzhda.ID
LEFT JOIN
(SELECT 'Weekly Reporting' AS ID, SUM(Active.OtchCena * Active.QTY) AS Stock, COUNT(*) AS Gamma FROM
(
SELECT SUM(SD.QTY) AS QTY, K.Kod1 AS Kod, K.Ime1 as Ime, ISNULL(Ceni.Cena,0) AS OtchCena
FROM dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
INNER JOIN T2014.dbo.Klas_SMC_Ceni Ceni ON Ceni.SMCId = K.ID AND Ceni.NomCena = 11
LEFT JOIN T2012.dbo.sgQualityScores QS ON QS.SMCId = K.ID
WHERE SD.Store IN (
	SELECT  Id = 8  --Sofia
    UNION
	SELECT  Id = 242 --Mezhdinen
    UNION
	SELECT  Id 
	FROM    dbo.MOL_Nashi 
	WHERE   ID_Podchinenie = 8
) --AND SD.Period < 9 AND QS.SMCId IS NULL  --Flip on or off to get dead stock.
GROUP BY SD.Iv, K.Kod1, K.Ime1,Ceni.Cena HAVING SUM(SD.QTY)>0) Active) Sofia ON Sofia.ID = Nuzhda.ID
LEFT JOIN
(SELECT 'Weekly Reporting' AS ID, SUM(Active.OtchCena * Active.QTY) AS Stock, COUNT(*) AS Gamma FROM
(
SELECT SUM(SD.QTY) AS QTY, K.Kod1 AS Kod, K.Ime1 as Ime, ISNULL(Ceni.Cena,0) AS OtchCena
FROM dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
INNER JOIN T2014.dbo.Klas_SMC_Ceni Ceni ON Ceni.SMCId = K.ID AND Ceni.NomCena = 11
LEFT JOIN T2012.dbo.sgQualityScores QS ON QS.SMCId = K.ID
WHERE SD.Store IN (
	SELECT  Id = 239  --Byala
    UNION
	SELECT  Id 
	FROM    dbo.MOL_Nashi 
	WHERE   ID_Podchinenie = 239
) --AND SD.Period < 9 AND QS.SMCId IS NULL  --Flip on or off to get dead stock.
GROUP BY SD.Iv, K.Kod1, K.Ime1,Ceni.Cena HAVING SUM(SD.QTY)>0) Active) Byala ON Byala.ID = Nuzhda.ID
LEFT JOIN
(SELECT 'Weekly Reporting' AS ID, SUM(Active.OtchCena * Active.QTY) AS Stock, COUNT(*) AS Gamma FROM
(
SELECT SUM(SD.QTY) AS QTY, K.Kod1 AS Kod, K.Ime1 as Ime, ISNULL(Ceni.Cena,0) AS OtchCena
FROM dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
INNER JOIN T2014.dbo.Klas_SMC_Ceni Ceni ON Ceni.SMCId = K.ID AND Ceni.NomCena = 11
LEFT JOIN T2012.dbo.sgQualityScores QS ON QS.SMCId = K.ID
WHERE SD.Store IN (
	SELECT  Id = 245  --Ruse
    UNION
	SELECT  Id 
	FROM    dbo.MOL_Nashi 
	WHERE   ID_Podchinenie = 245
) --AND SD.Period < 9 AND QS.SMCId IS NULL  --Flip on or off to get dead stock.
GROUP BY SD.Iv, K.Kod1, K.Ime1,Ceni.Cena HAVING SUM(SD.QTY)>0) Active) Ruse ON Ruse.ID = Nuzhda.ID
LEFT JOIN
(SELECT 'Weekly Reporting' AS ID, SUM(Active.OtchCena * Active.QTY) AS Stock, COUNT(*) AS Gamma FROM
(
SELECT SUM(SD.QTY) AS QTY, K.Kod1 AS Kod, K.Ime1 as Ime, ISNULL(Ceni.Cena,0) AS OtchCena
FROM dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
INNER JOIN T2014.dbo.Klas_SMC_Ceni Ceni ON Ceni.SMCId = K.ID AND Ceni.NomCena = 11
LEFT JOIN T2012.dbo.sgQualityScores QS ON QS.SMCId = K.ID
WHERE SD.Store IN (
	SELECT  Id = 279  --Varna
    UNION
	SELECT  Id 
	FROM    dbo.MOL_Nashi 
	WHERE   ID_Podchinenie = 279
) --AND SD.Period < 9 AND QS.SMCId IS NULL  --Flip on or off to get dead stock.
GROUP BY SD.Iv, K.Kod1, K.Ime1,Ceni.Cena HAVING SUM(SD.QTY)>0) Active) Varna ON Varna.ID = Nuzhda.ID
LEFT JOIN
(SELECT 'Weekly Reporting' AS ID, SUM(Active.OtchCena * Active.QTY) AS Stock, COUNT(*) AS Gamma FROM
(
SELECT SUM(SD.QTY) AS QTY, K.Kod1 AS Kod, K.Ime1 as Ime, ISNULL(Ceni.Cena,0) AS OtchCena
FROM dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
INNER JOIN T2014.dbo.Klas_SMC_Ceni Ceni ON Ceni.SMCId = K.ID AND Ceni.NomCena = 11
LEFT JOIN T2012.dbo.sgQualityScores QS ON QS.SMCId = K.ID
WHERE SD.Store IN (
	SELECT  Id = 278  --Veliko Turnovo
    UNION
	SELECT  Id 
	FROM    dbo.MOL_Nashi 
	WHERE   ID_Podchinenie = 278
) --AND SD.Period < 9 AND QS.SMCId IS NULL  --Flip on or off to get dead stock.
GROUP BY SD.Iv, K.Kod1, K.Ime1,Ceni.Cena HAVING SUM(SD.QTY)>0) Active) VT ON VT.ID = Nuzhda.ID
LEFT JOIN
(SELECT 'Weekly Reporting' AS ID,COUNT(*) AS Kol FROM #sgRazpredelenieReport WHERE SofiaToByala > 0) SofiaToByala ON SofiaToByala.ID = Nuzhda.ID
LEFT JOIN
(SELECT 'Weekly Reporting' AS ID,COUNT(*) AS Kol FROM #sgRazpredelenieReport WHERE SofiaToVarna > 0) SofiaToVarna ON SofiaToVarna.ID = Nuzhda.ID
LEFT JOIN
(SELECT 'Weekly Reporting' AS ID,COUNT(*) AS Kol FROM #sgRazpredelenieReport WHERE SofiaToRuse > 0) SofiaToRuse ON SofiaToRuse.ID = Nuzhda.ID
LEFT JOIN
(SELECT 'Weekly Reporting' AS ID,COUNT(*) AS Kol FROM #sgRazpredelenieReport WHERE SofiaToVT > 0) SofiaToVT ON SofiaToVT.ID = Nuzhda.ID;

