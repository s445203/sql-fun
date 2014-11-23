/*
 * OPISANIE:  Samo go pusni!  Ne pipai Nishto!
 *
 *  Pokazva tablicata na dotavchici koito izliza ot SMCQuality.sql koito
 *  imat nuzhda or poruchka, no bez da smiata cifrite.
 *  Za da se promeniat cifrite, triabva purvo da se pusne SMCQuality.sql skript - toi e osnovniat koito podnoviava
 *  dannite
 */
/*
 * VERSION: 1
 *
 * Release History:
 * VERSION 1: 27.07.2014 Initial release.  Display the detailed SMC table computed by the quality calculation.
 */
/*
 * Display the prioritised orders report
 */
SELECT G.Code AS Grupa,G.Ime AS Dostavchik,AVG(QS.Quality) AS 'Sredno Kachestvo na SMC s Nuzhda za poruchvane',
	   SUM(Orders.ChistaZaiavka * K.CenaO1) AS 'Stoinost na cialata poruchka', COUNT(*) AS 'Broi SMCta za poruchvane',SUM(Orders.DnevnaZagubaOtZakusnenieBGN) AS DnevnaZagubaOtZakusnenieBGN
FROM T2012.dbo.sgQualityScores QS 
LEFT JOIN T2012.dbo.sgOrderNeed Orders ON QS.SMCId = Orders.SMCId
LEFT JOIN T2014.dbo.Klas_SMC K ON K.ID = QS.SMCID
LEFT JOIN T2014.dbo.Grupi_SMC G ON G.Code = K.Grupi
WHERE Orders.SMCId IS NOT NULL AND Orders.ChistaZaiavka > 0
GROUP BY G.Ime,G.Code
ORDER BY DnevnaZagubaOtZakusnenieBGN DESC;