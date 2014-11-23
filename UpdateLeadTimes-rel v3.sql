/*
 * VERSION: 3
 *
 * Release History:
 * VERSION 3: 13.11.2014 Changed Febi back to 0.75
 * VERSION 2: 5.11.2014 Changed Febi from 0.5 to 1
 * VERSION 1: July 2014
 */
/*IF NOT OBJECT_ID('T2012.dbo.sgLeadTimes')       IS NULL DROP TABLE T2012.dbo.sgLeadTimes;
CREATE TABLE T2012.dbo.sgLeadTimes
(   
	Grupa INT NULL,
	LeadTime Real NULL	
); 
CREATE CLUSTERED INDEX sgIdxLT ON T2012.dbo.sgLeadTimes(Grupa);*/

TRUNCATE TABLE T2012.dbo.sgLeadTimes;
INSERT INTO T2012.dbo.sgLeadTimes VALUES (297,	3); --3 A INDUSTRIES CHINA
INSERT INTO T2012.dbo.sgLeadTimes VALUES (29921,	3); --	ADD АМОРТИСЬОРИ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (5500,	1.5); --	AGIS ZAVORE-SLOVENIA-СЕРВОУС.АМБР.ПОМ.РЕМ.К-Т
INSERT INTO T2012.dbo.sgLeadTimes VALUES (925,	1.5); --	AIRKRAFT, TURKEY
INSERT INTO T2012.dbo.sgLeadTimes VALUES (6667,	2); --	AL-KO
INSERT INTO T2012.dbo.sgLeadTimes VALUES (296,	1); --	ALL RIDE EDCO EINDHOVEN B.V HOLLAND
INSERT INTO T2012.dbo.sgLeadTimes VALUES (871,	1); --	ASSO MARMITTE-ITALY-АСПУХОВА СИСТЕМА
INSERT INTO T2012.dbo.sgLeadTimes VALUES (852,	2); --	AUGER,GERMANY
INSERT INTO T2012.dbo.sgLeadTimes VALUES (8400,	2); --	AYDINSAN-TURKEY-ТРЕСЧОТКИ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (36,	1.5); --	BICMA-ITALY-ТАБЕЛИ-СТИКЕРИ, ADR ОБОРУДВАНЕ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (2931,	1); --	BUSINESS LINES LTD - UK - ЧЕКПОЙНТ МАРКЕРИ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (375,	1.5); --	COJALI-SPAIN-ВИСКОСЪЕДИНИТЕЛИ,ПЕРКИ,ВЪЗДУШНА СИСТЕ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (2232,	1); --	COMPASELECT-УРЕД ЗА ИЗМЕРВАНЕ НА АНТИФРИЗ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (8310,	1); --	CONTINENTAL CONTITECH PHOENIX-GERMANY-ВЪЗД ВЪЗГЛ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (8100,	1); --	COSPEL-ЕДРОГАБАРИТНИ ЧАСТИ, ITALY
INSERT INTO T2012.dbo.sgLeadTimes VALUES (379,	1.5); --	CUMMINS NV,BELGIUM
INSERT INTO T2012.dbo.sgLeadTimes VALUES (2222,	1.5); --	DAKEN-ITALY-КУТИИ ЗА ПОЖАРОГАСИТЕЛИ И ИНСТРУМЕНТИ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (9910,	2); --	DASTERI-GREECE-ОСВЕТЛЕНИЕ, СТОПОВЕ, ГАБАРИТИ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (7111,	2); --	DAYCO-ITALY-РЕМЪЦИ И РОЛКИ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (9500,	3); --	DEPO AUTO LEMPS-ФАРОВЕ, МИГАЧИ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (2224,	1.5); --	DOMAR-ITALY-КАЛНИЦИ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (2993,	3); --	DONG XING,CHINA
INSERT INTO T2012.dbo.sgLeadTimes VALUES (299,	3); --	EAST CRACE,CHINA
INSERT INTO T2012.dbo.sgLeadTimes VALUES (2800,	2); --	EKU-TURKEY-БАРАБАНИ И СПИРАЧНИ ДИСКОВЕ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (1446,	3); --	EURO07
INSERT INTO T2012.dbo.sgLeadTimes VALUES (322,	1); --	EUROPEAN TRUCK TRAILER PARTS bvba
INSERT INTO T2012.dbo.sgLeadTimes VALUES (298,	3); --	EVER BRIGHT CHINA
INSERT INTO T2012.dbo.sgLeadTimes VALUES (444,	0.75); --	FEBI-GERMANY-РАЗНИ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (43,	1); --	FEDERAL MOGUL-BELGIUM-ДВИГАТЕЛНА ГРУПА, ОКАЧВАТЕ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (462,	3); --	FERSA-SPAIN-ЛАГЕРИ И РЕМОНТНИ КОМПЛЕКТИ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (355,	1); --	FOMCO
INSERT INTO T2012.dbo.sgLeadTimes VALUES (9100,	2); --	FRENOTRUCK-РАЗНИ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (376,	1); --	FRIG AIR S.P.A.-ITALY-РАДИАТОРИ, ИНТЕРКУЛЕР
INSERT INTO T2012.dbo.sgLeadTimes VALUES (783,	3); --	FRISTOM-POLAND-ОСВЕТЛЕНИЕ, ГАБАРИТИ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (7600,	1); --	FTE/ASPOCK/RINGFEDER-GERMANY/AUSTRIA-СЕРВОУСИЛВАТЕ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (7000,	2); --	GATES POWER TRANSMISSION EUROPE, BELGIUM
INSERT INTO T2012.dbo.sgLeadTimes VALUES (357,	1); --	HELLA KGA - GERMANY - ОСВЕТЛЕНИЕ, ОХЛАДИТЕЛНА С-МА
INSERT INTO T2012.dbo.sgLeadTimes VALUES (3900,	3); --	HUSHAN TRANSPORTATION CO LTD-ОБОРУДВАНЕ ЗА ВРАТИ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (29,	2); --	INTERTRUCK-HOLLAND-РАЗНИ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (731,	2); --	JOHNSON CONTROLS AUTOBATERIEN, GERMANY
INSERT INTO T2012.dbo.sgLeadTimes VALUES (888,	2); --	KAHVECI-SFK TRUCK-E.U.-ЕДРОГАБ. ЧАСТИ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (1111,	4); --	KANCA-СПИРАЧНИ КАМЕРИ, ВИСЯЩИ ЛАГЕРИ, TURKEY
INSERT INTO T2012.dbo.sgLeadTimes VALUES (2991,	3); --	KELI AUTO,CHINA
INSERT INTO T2012.dbo.sgLeadTimes VALUES (321,	2); --	KIPA-KONGSBERG-NORWAY-ВЪЗДУШНА СИСТЕМА
INSERT INTO T2012.dbo.sgLeadTimes VALUES (2700,	2); --	KM AUTO-GERMANY-СЪЕДИНИТЕЛИ И ОКАЧВАНЕ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (31,	1.5); --	KNORR-BREMSE - GERMANY - ВЪЗДУШНА СИСТЕМА
INSERT INTO T2012.dbo.sgLeadTimes VALUES (461,	1); --	LEMA-ITALY-ЧАСТИ ПО ОКАЧВАНЕТО И ДВИГАТЕЛЯ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (785,	3); --	LUMAG-POLAND-НАКЛАДКИ, НИТОВЕ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (932,	1.5); --	MAGNETON, CZECH REPUBLIC
INSERT INTO T2012.dbo.sgLeadTimes VALUES (700,	1.5); --	MANN FILTER-GERMANY-ФИЛТРИ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (3333,	1.5); --	MARTEX-РАЗНИ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (29981,	1.5); --	MAURELLI
INSERT INTO T2012.dbo.sgLeadTimes VALUES (72,	3); --	MEKRA-GERMANY-ОГЛЕДАЛА
INSERT INTO T2012.dbo.sgLeadTimes VALUES (5550,	2); --	MENBERS-ITALY-ЕЛ. КАБЕЛИ, ЕЛ. ОБОРД. ЗА ИНСТАЛАЦИИ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (324,	1.5); --	MERITOR, GERMANY
INSERT INTO T2012.dbo.sgLeadTimes VALUES (2999,	3); --	METEC ESTONIA
INSERT INTO T2012.dbo.sgLeadTimes VALUES (445,	1.5); --	MEYLE,GERMANY
INSERT INTO T2012.dbo.sgLeadTimes VALUES (293,	1.5); --	NEW WORLD AIR BRAKE-UK-KNORR BREMSE
INSERT INTO T2012.dbo.sgLeadTimes VALUES (29915,	3); --	NINGBO TRUPOW IMP. & EXP.CO.LTD.
INSERT INTO T2012.dbo.sgLeadTimes VALUES (29916,	3); --	NINGBO WOSIMAN
INSERT INTO T2012.dbo.sgLeadTimes VALUES (295,	3); --	OLLO HID XENON, CHINA
INSERT INTO T2012.dbo.sgLeadTimes VALUES (373,	0.5); --	OPOLTRANS-РАЗНИ, POLAND
INSERT INTO T2012.dbo.sgLeadTimes VALUES (378,	3); --	PARTS FACTORY, HOLLAND
INSERT INTO T2012.dbo.sgLeadTimes VALUES (688,	2); --	PHILLIPS, NARVA-HOLLAND-ЕЛ. КРУШКИ-PLP-NARVA-OSRAM
INSERT INTO T2012.dbo.sgLeadTimes VALUES (34,	3); --	PROPLAST-GERMANY-ОСВЕТЛЕНИЕ, СТОПОВЕ, ГАБАРИТИ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (9300,	2); --	REMY-HUNGARY/U.S.A-СТАРТЕРИ И АЛТЕРНАТОРИ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (358,	2); --	ROSTAR AUTOMOTIVE, GERMANY, ЧАСТИ ПО ОКАЧАВАНЕТО
INSERT INTO T2012.dbo.sgLeadTimes VALUES (2995,	3); --	RUIAN EHUA AUTO PARTS CO,CHINA
INSERT INTO T2012.dbo.sgLeadTimes VALUES (8500,	2); --	SAMPA-ОКАЧВАНЕ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (356,	1); --	SC AUTONET-ROMANIA-РАЗНИ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (851,	2); --	SEM-TURKYE-ОКАЧВАНЕ-ВОДНИ СЪЕДИНЕНИЯ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (2992,	3); --	SHANDONG LUDA,CHINA-СПИРАЧНИ ДИСКОВЕ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (2998,	1.5); --	SUPER RICAMBI
INSERT INTO T2012.dbo.sgLeadTimes VALUES (2223,	1.5); --	TAKLER-ITALY-КАЗАНЧЕТА ЗА ВОДА, БРОНИ И АКСЕСОАРИ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (323,	1); --	TECHMOT Sp. z o.o., POLAND
INSERT INTO T2012.dbo.sgLeadTimes VALUES (6666,	1); --	TENNECO-MONROE-BELGIUM-АМОРТИСЬОРИ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (2910,	3); --	TINTAI SINOBASE IMPEX-CHINA-ПРЕДПАЗ МЕХ, РЕЗЕРВОАР
INSERT INTO T2012.dbo.sgLeadTimes VALUES (281,	3); --	TRUCK TECHNIC - BEY FREN OTOTMOTIV-TURKEY-ВЪЗДУШНА
INSERT INTO T2012.dbo.sgLeadTimes VALUES (29912,	3); --	UNIBRAKE
INSERT INTO T2012.dbo.sgLeadTimes VALUES (35,	1); --	UNITRUCK-GREAT BRITAIN-ОГЛЕДАЛА
INSERT INTO T2012.dbo.sgLeadTimes VALUES (291,	0.25); --	VADEN-YPS-TURKEY-РЕМ.К-ТИ ЗА КОМПРЕСОРИ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (90,	1.5); --	VIGNAL-FRANCE-СТОПОВЕ, ГАБАРИТИ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (3000,	1.5); --	WABCO-GERMANY-SFK TRUCK-ВЪЗДУШНА СИСТЕМА
INSERT INTO T2012.dbo.sgLeadTimes VALUES (8800,	1.5); --	WABCO-GERMANY-ВЪЗДУШНА СИСТЕМА
INSERT INTO T2012.dbo.sgLeadTimes VALUES (443,	1); --	WAECO-GERMANY
INSERT INTO T2012.dbo.sgLeadTimes VALUES (11138,	3); --	WENLING - ГАЙКОВЕРТ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (29917,	3); --	WENZHOU BONAI AUTO RADIATOR CO.LTD
INSERT INTO T2012.dbo.sgLeadTimes VALUES (29919,	3); --	WENZHOU FORTUNE IMP & EXP CO.,LTD
INSERT INTO T2012.dbo.sgLeadTimes VALUES (784,	3); --	WESEM-POLAND-ХАЛОГЕНИ, СВЕТЛИНИ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (446,	1); --	WINKLER
INSERT INTO T2012.dbo.sgLeadTimes VALUES (2231,	2); --	WISTRA-GERMANY-ГРУПАЖНИ ДЪСКИ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (29918,	3); --	ZHEJIANG DEZHONG AUTO PARTS MANUFACTURING CO
INSERT INTO T2012.dbo.sgLeadTimes VALUES (2997,	3); --	ZHEJIANG YA ZHI XING AUTOMOBILE LTD
INSERT INTO T2012.dbo.sgLeadTimes VALUES (11171,	0.03); --	АКСО МАНИЯ-ЕООД / АВТОКОМПЛЕКТ ООД
INSERT INTO T2012.dbo.sgLeadTimes VALUES (6120,	0.03); --	АУТО МОТО ДИЗАЙН ООД-ВЕРИГИ, КАЛОБРАНИ И СТЕЛКИ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (1118868,	0.03); --	АУТО ХИТ ООД
INSERT INTO T2012.dbo.sgLeadTimes VALUES (2610,	0.10); --	АУТОПАРС 2000 АСЕНОВГР-ФАРОВЕ, СТОП, ГАБ, АКСЕСОАР
INSERT INTO T2012.dbo.sgLeadTimes VALUES (11234,	0.03); --	БАТЕРИЯ АД
INSERT INTO T2012.dbo.sgLeadTimes VALUES (11177,	0.03); --	БИКЕ-ЕООД
INSERT INTO T2012.dbo.sgLeadTimes VALUES (11221,	0.03); --	БУЛ МАКС ГАЗ ООД
INSERT INTO T2012.dbo.sgLeadTimes VALUES (6910,	0.03); --	ВАЛЕРИЙ СОФИЯ-КЛЮЧОВЕ, АКСЕСОАРИ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (2500,	3); --	ВЕРИГИ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (9999,	0.03); --	ВЕРИЛА-BG-АНТИФРИЗ, СПИР. ТЕЧНОСТИ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (1114488,	0.03); --	ГАРВАН ЕООД
INSERT INTO T2012.dbo.sgLeadTimes VALUES (7700,	0.03); --	ДОБАВКИ-ТАУРУС ИНТЕРНЕШЪНЪЛ ТРЕЙДИНГ…STP
INSERT INTO T2012.dbo.sgLeadTimes VALUES (8900,	0.03); --	ЕВРОМАРКЕТ БРД-ИНСТРУМЕНТИ, КЛЮЧОВЕ, ТАКАЛАМИТИ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (11212,	0.67); --	ЕВРОПРИНТ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (7555,	0.25); --	ЕВРОСЕРВИЗ ТАНДЕР-GERMANY-ОРИГ.РЕЗ. ЧАСТИ MERCEDES
INSERT INTO T2012.dbo.sgLeadTimes VALUES (11146,	0.03); --	ИН ЛОКО ЕТ-ПРЕПАРАТ ЗА РЪЦЕ МАРИЦА
INSERT INTO T2012.dbo.sgLeadTimes VALUES (11187,	0.03); --	ИНДЪСТРИЪЛ ТРЕЙДИНГ ООД
INSERT INTO T2012.dbo.sgLeadTimes VALUES (11222,	0.03); --	КиП ИНЖЕНЕРИНГ ООД
INSERT INTO T2012.dbo.sgLeadTimes VALUES (11179,	0.03); --	КОРТЕН-ЕООД
INSERT INTO T2012.dbo.sgLeadTimes VALUES (1118888,	0.23); --	МАКСИМАЛ РАЗГРАД-ООД
INSERT INTO T2012.dbo.sgLeadTimes VALUES (1666,	0.03); --	МАСЛО ШЕЛ-МОБИЛУБ ЕООД-SHELL-HOLLAND-МАСЛА
INSERT INTO T2012.dbo.sgLeadTimes VALUES (11126,	0.03); --	МЕДИКА ЗДРАВЕ ЕООД-АВТОАПТЕЧКА-БГ
INSERT INTO T2012.dbo.sgLeadTimes VALUES (11129,	0.03); --	МИТ ООД
INSERT INTO T2012.dbo.sgLeadTimes VALUES (11156,	0.5); --	МУЛТИПРИНТ - ООД
INSERT INTO T2012.dbo.sgLeadTimes VALUES (11142,	0.03); --	ОЛИМП - ЕООД
INSERT INTO T2012.dbo.sgLeadTimes VALUES (11143,	0.03); --	ПАСАТ-МН ООД
INSERT INTO T2012.dbo.sgLeadTimes VALUES (11166,	0.07); --	ПОЖАРНА ТЕХНИКА - ООД
INSERT INTO T2012.dbo.sgLeadTimes VALUES (5000,	0.03); --	СТЕАЛИТ ГАРА ЯНА-BULGARIA-МАСЛА, ГРЕС
INSERT INTO T2012.dbo.sgLeadTimes VALUES (111421,1); --	ТЕКС ТРЕЙД -ЕООД
INSERT INTO T2012.dbo.sgLeadTimes VALUES (921,	0.10); --	ТЕХНО АКТАШ АД-ВЪЗДУШНИ ВЪЗГЛАВНИЦИ-AIRTECH
