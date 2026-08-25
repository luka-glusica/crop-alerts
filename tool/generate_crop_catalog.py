# -*- coding: utf-8 -*-
"""Generates assets/content/crops_sr.json and crops_en.json from one source,
so the two languages cannot drift structurally."""
import json, collections

def band(lo, hi):
    """Infection window: the leaf passed through this temperature at some point.

    Right for pathogens, where a few hours in the favourable range while the
    leaf is wet is enough. Wrong for anything describing the character of a
    whole day -- a 32 C day whose dawn minimum touched 21 is not a mild day.
    """
    return {"type": "rangeOverlap", "lower": "minTemperature", "upper": "maxTemperature",
            "min": lo, "max": hi}

def avg_band(lo, hi):
    """The day as a whole sat in this range. Right for insect activity."""
    return {"type": "metricBand", "metric": "averageTemperature", "min": lo, "max": hi}

def consecutive(days, condition):
    return {"type": "consecutiveDays", "days": days, "condition": condition}

def humid_min(v):
    return {"type": "metricThreshold", "metric": "minHumidity", "comparator": "greaterThan", "value": v}

def humid_max(v):
    return {"type": "metricThreshold", "metric": "maxHumidity", "comparator": "greaterThan", "value": v}

def temp_above(v):
    return {"type": "metricThreshold", "metric": "maxTemperature", "comparator": "greaterThan", "value": v}

def temp_below(v):
    return {"type": "metricThreshold", "metric": "minTemperature", "comparator": "lessThan", "value": v}

def dry_air(v):
    return {"type": "metricThreshold", "metric": "minHumidity", "comparator": "lessThan", "value": v}

def rain_at_least(days, mm):
    return {"type": "sumOverDays", "metric": "precipitation", "days": days,
            "comparator": "atLeast", "value": mm}

def rain_at_most(days, mm):
    return {"type": "sumOverDays", "metric": "precipitation", "days": days,
            "comparator": "atMost", "value": mm}

def all_of(*c):
    return {"type": "allOf", "conditions": list(c)}

def rule(crop, threat, name, condition=None, weight=1):
    assert condition is not None
    r = {"id": f"{crop}.{threat}.{name}", "threatId": threat, "condition": condition}
    if weight != 1:
        r["weight"] = weight
    return r

CROPS = []

def crop(cid, season, names, threats):
    CROPS.append({"id": cid, "season": season, "names": names, "threats": threats})

def threat(tid, ttype, names, descriptions, prevention, response, rules):
    return {"id": tid, "type": ttype, "names": names, "descriptions": descriptions,
            "prevention": prevention, "response": response, "rules": rules}

# ---------------------------------------------------------------- paradajz
crop("paradajz", (5, 10), {"sr": "Paradajz", "en": "Tomato"}, [
    threat("plamenjaca", "fungalDisease",
        {"sr": "Plamenjača", "en": "Late blight"},
        {"sr": "Gljivično oboljenje koje se širi po umerenim temperaturama i dugotrajnoj vlazi na listu; daje tamne pege sa svetlim rubom, a na plodovima tvrdu smeđu trulež.",
         "en": "A fungal disease that spreads at mild temperatures when the leaf stays wet, leaving dark spots with a pale edge and a firm brown rot on the fruit."},
        {"sr": ["Zalivanje isključivo u koren, nikada preko lista.",
                "Zakidanje zaperaka i donjeg lišća radi provetravanja.",
                "Razmak sadnje dovoljan da se list brzo osuši posle kiše.",
                "Plodored od najmanje tri godine."],
         "en": ["Water at the root only, never over the leaves.",
                "Pinch out side shoots and lower leaves so air can move through.",
                "Space plants far enough apart that leaves dry quickly after rain.",
                "Rotate with at least a three-year gap."]},
        {"sr": ["Mehaničko uklanjanje obolelog lišća i iznošenje iz bašte.",
                "Prskanje dozvoljenim bakarnim preparatom ili čajem od rastavića.",
                "Prekid orošavanja i pojačano provetravanje.",
                "Berba zdravih plodova pre nego što zaraza napreduje."],
         "en": ["Remove diseased leaves and take them out of the garden.",
                "Spray with an approved copper preparation or horsetail tea.",
                "Stop overhead watering and improve ventilation.",
                "Pick healthy fruit before the infection advances."]},
        [rule("paradajz", "plamenjaca", "uslovi-za-infekciju",
              all_of(band(15, 25), humid_min(60)), weight=2),
         rule("paradajz", "plamenjaca", "padavine", rain_at_least(2, 10))]),

    threat("crna-pegavost", "fungalDisease",
        {"sr": "Crna pegavost", "en": "Early blight"},
        {"sr": "Koncentrične tamne pege na starijem lišću koje se šire naviše; pogoduje joj toplo vreme sa smenom vlaženja i sušenja lista.",
         "en": "Dark concentric spots on older leaves that spread upward, favoured by warm weather where the leaf repeatedly wets and dries."},
        {"sr": ["Malčiranje tla, da kišne kapi ne prskaju zemlju na donje lišće.",
                "Uravnotežena ishrana azotom.",
                "Uklanjanje i uništavanje biljnih ostataka posle berbe."],
         "en": ["Mulch the soil so rain cannot splash it onto the lower leaves.",
                "Keep nitrogen feeding balanced.",
                "Clear and destroy plant debris after harvest."]},
        {"sr": ["Uklanjanje najstarijih zaraženih listova.",
                "Tretman dozvoljenim bakarnim preparatom.",
                "Zalivanje ujutru, da list prenoći suv."],
         "en": ["Strip the oldest infected leaves.",
                "Treat with an approved copper preparation.",
                "Water in the morning so leaves go into the night dry."]},
        [rule("paradajz", "crna-pegavost", "uslovi-za-infekciju",
              all_of(band(24, 29), humid_min(55)), weight=2)]),

    threat("paradajzov-moljac", "pest",
        {"sr": "Paradajzov moljac", "en": "Tomato leafminer"},
        {"sr": "Larve buše mine u listu i ulaze u plod; generacije se smenjuju sve brže kako temperatura raste.",
         "en": "Larvae mine the leaves and bore into the fruit, with generations following each other faster as it gets warmer."},
        {"sr": ["Feromonske klopke za praćenje leta.",
                "Uklanjanje i uništavanje napadnutih plodova i listova.",
                "Mreže protiv insekata na otvorima plastenika."],
         "en": ["Pheromone traps to track the flight.",
                "Remove and destroy attacked fruit and leaves.",
                "Insect netting over greenhouse openings."]},
        {"sr": ["Gusto postavljanje feromonskih klopki radi masovnog izlovljavanja.",
                "Preparati na bazi Bacillus thuringiensis dok su larve mlade.",
                "Uklanjanje miniranih listova pre nego što larve pređu na plod."],
         "en": ["Set pheromone traps densely for mass trapping.",
                "Use Bacillus thuringiensis preparations while larvae are young.",
                "Strip mined leaves before the larvae move into the fruit."]},
        [rule("paradajz", "paradajzov-moljac", "toplo", avg_band(20, 32)),
         rule("paradajz", "paradajzov-moljac", "toplotni-talas",
              consecutive(3, temp_above(30)))]),

    threat("trulez-vrha-ploda", "other",
        {"sr": "Truljenje vrha ploda", "en": "Blossom-end rot"},
        {"sr": "Fiziološki poremećaj, a ne bolest: po vrućini i neredovnom zalivanju biljka ne stigne da prenese kalcijum do ploda, pa vrh ploda potamni i propadne. Ne prenosi se sa biljke na biljku.",
         "en": "A physiological disorder rather than a disease: in heat with uneven watering the plant cannot move calcium to the fruit, so its tip darkens and collapses. It does not spread from plant to plant."},
        {"sr": ["Ravnomerno zalivanje, bez naglih sušnih prekida.",
                "Malčiranje radi zadržavanja vlage u zemljištu.",
                "Izbegavanje viška azotnih đubriva."],
         "en": ["Water evenly, without sudden dry spells.",
                "Mulch to hold moisture in the soil.",
                "Avoid overdoing nitrogen fertiliser."]},
        {"sr": ["Uspostavljanje redovnog ritma zalivanja manjim količinama.",
                "Hitno malčiranje radi smanjenja isparavanja.",
                "Uklanjanje zahvaćenih plodova da biljka ne troši snagu na njih."],
         "en": ["Return to a steady rhythm of smaller, regular waterings.",
                "Mulch straight away to cut evaporation.",
                "Pick off affected fruit so the plant stops spending on it."]},
        [rule("paradajz", "trulez-vrha-ploda", "vrucina-i-susa",
              all_of(temp_above(30), rain_at_most(5, 5)), weight=2)]),
])

# ---------------------------------------------------------------- krompir
crop("krompir", (3, 9), {"sr": "Krompir", "en": "Potato"}, [
    threat("plamenjaca", "fungalDisease",
        {"sr": "Plamenjača krompira", "en": "Potato late blight"},
        {"sr": "Najopasnija bolest krompira; po vlažnom vremenu za nekoliko dana može uništiti celu cimu, a spore sa lista dospevaju do krtola.",
         "en": "The most damaging potato disease: in wet weather it can destroy the whole haulm within days, and spores wash from the leaves down to the tubers."},
        {"sr": ["Sertifikovano, zdravo seme.",
                "Visoko zagrtanje, da spore sa lista ne dopru do krtola.",
                "Plodored i uništavanje samoniklih biljaka.",
                "Preventivni bakarni preparati pred najavljeni vlažan period."],
         "en": ["Certified, healthy seed potatoes.",
                "Earth up high so spores cannot reach the tubers.",
                "Rotate crops and destroy volunteer plants.",
                "Apply preventive copper ahead of a forecast wet spell."]},
        {"sr": ["Prskanje dozvoljenim bakarnim preparatima.",
                "Tretman čajem od rastavića.",
                "Uklanjanje nadzemne cime pri jakoj zarazi, dve nedelje pre vađenja.",
                "Vađenje krtola po suvom vremenu."],
         "en": ["Spray with approved copper preparations.",
                "Treat with horsetail tea.",
                "Cut and remove the haulm in a heavy infection, two weeks before lifting.",
                "Lift the tubers in dry weather."]},
        [rule("krompir", "plamenjaca", "uslovi-za-infekciju",
              all_of(band(15, 21), humid_min(65)), weight=2),
         rule("krompir", "plamenjaca", "padavine", rain_at_least(3, 15))]),

    threat("crna-pegavost", "fungalDisease",
        {"sr": "Crna pegavost", "en": "Early blight"},
        {"sr": "Suva pegavost lista sa koncentričnim krugovima; javlja se po toplijem vremenu i na oslabljenim biljkama pred kraj vegetacije.",
         "en": "Dry leaf spotting with concentric rings, appearing in warmer weather and on plants weakening towards the end of the season."},
        {"sr": ["Uravnotežena ishrana, jer oslabljene biljke prve obolevaju.",
                "Malčiranje tla ispod biljaka.",
                "Uklanjanje biljnih ostataka posle vađenja."],
         "en": ["Balanced feeding, since weakened plants go down first.",
                "Mulch the soil under the plants.",
                "Clear plant debris after lifting."]},
        {"sr": ["Uklanjanje najstarijih zaraženih listova.",
                "Tretman dozvoljenim bakarnim preparatom.",
                "Prihrana radi jačanja biljke."],
         "en": ["Remove the oldest infected leaves.",
                "Treat with an approved copper preparation.",
                "Feed the crop to strengthen it."]},
        [rule("krompir", "crna-pegavost", "uslovi-za-infekciju",
              all_of(band(24, 29), humid_min(55)), weight=2)]),

    threat("zlatica", "pest",
        {"sr": "Krompirova zlatica", "en": "Colorado potato beetle"},
        {"sr": "Odrasle jedinke i larve gole list do nervature; po toplom i suvom vremenu razvoj se ubrzava i generacije se preklapaju.",
         "en": "Adults and larvae strip the leaves to the veins; in warm dry weather development speeds up and generations overlap."},
        {"sr": ["Plodored, sa parcelom što dalje od prošlogodišnje.",
                "Ranija sadnja radi izbegavanja najjačeg napada.",
                "Redovan pregled naličja listova i uništavanje legala jaja."],
         "en": ["Rotate, putting the plot as far as possible from last year's.",
                "Plant early to dodge the heaviest attack.",
                "Check leaf undersides regularly and crush egg clusters."]},
        {"sr": ["Ručno sakupljanje odraslih jedinki i legala jaja.",
                "Preparati na bazi Bacillus thuringiensis var. tenebrionis dok su larve mlade.",
                "Uklanjanje jako oštećene cime."],
         "en": ["Hand-pick adults and egg clusters.",
                "Use Bacillus thuringiensis var. tenebrionis while larvae are young.",
                "Remove badly stripped haulm."]},
        [rule("krompir", "zlatica", "toplo-i-suvo",
              all_of(temp_above(25), rain_at_most(3, 3)), weight=2)]),

    threat("pucanje-krtola", "other",
        {"sr": "Pucanje i deformacije krtola", "en": "Tuber cracking"},
        {"sr": "Obilan pljusak posle sušnog perioda tera krtolu u nagli rast, pa ona puca ili razvija izraštaje. Napukle krtole ne podnose skladištenje.",
         "en": "A heavy downpour after a dry spell forces the tuber into sudden growth, so it splits or throws out knobs. Cracked tubers do not store."},
        {"sr": ["Ravnomerno zalivanje tokom formiranja krtola.",
                "Malčiranje i zagrtanje radi stabilnije vlage u zemljištu."],
         "en": ["Water evenly while the tubers are forming.",
                "Mulch and earth up to keep soil moisture steadier."]},
        {"sr": ["Postepeno vraćanje zalivanja umesto jednog velikog obroka.",
                "Vađenje po suvom vremenu i odvajanje napuklih krtola pri skladištenju."],
         "en": ["Bring watering back gradually rather than in one large dose.",
                "Lift in dry weather and sort cracked tubers out before storing."]},
        [rule("krompir", "pucanje-krtola", "pljusak-posle-suse",
              rain_at_least(2, 30), weight=2)]),
])

# ---------------------------------------------------------------- krastavac
crop("krastavac", (5, 9), {"sr": "Krastavac", "en": "Cucumber"}, [
    threat("plamenjaca", "fungalDisease",
        {"sr": "Plamenjača krastavca", "en": "Cucumber downy mildew"},
        {"sr": "Uglaste žute pege ograničene nervima lista, sa sivkastom prevlakom na naličju; po vlažnom vremenu usev može propasti za nedelju dana.",
         "en": "Angular yellow patches bounded by the leaf veins, with a grey bloom underneath; in wet weather a crop can be lost within a week."},
        {"sr": ["Uzgoj na špaliru, radi bržeg sušenja lista.",
                "Izbegavanje kvašenja lišća pri zalivanju.",
                "Dovoljan razmak između biljaka."],
         "en": ["Grow on a trellis so leaves dry faster.",
                "Avoid wetting the foliage when watering.",
                "Leave enough space between plants."]},
        {"sr": ["Prekid orošavanja i prelazak na zalivanje u koren.",
                "Tretman dozvoljenim bakarnim preparatom.",
                "Uklanjanje prvih zaraženih listova i iznošenje iz bašte."],
         "en": ["Stop overhead watering and switch to the root.",
                "Treat with an approved copper preparation.",
                "Remove the first infected leaves and take them out of the garden."]},
        [rule("krastavac", "plamenjaca", "uslovi-za-infekciju",
              all_of(band(20, 27), humid_min(65)), weight=2),
         rule("krastavac", "plamenjaca", "padavine", rain_at_least(2, 10))]),

    threat("pepelnica", "fungalDisease",
        {"sr": "Pepelnica", "en": "Powdery mildew"},
        {"sr": "Beličasta prevlaka nalik brašnu na licu lista. Za razliku od plamenjače, traži toplo vreme i vlažan vazduh, ali suv list — zato se javlja i kad kiše nema.",
         "en": "A white, flour-like coating on the upper leaf surface. Unlike downy mildew it wants warmth and humid air but a dry leaf, so it appears even without rain."},
        {"sr": ["Razmak sadnje i uklanjanje donjih listova radi protoka vazduha.",
                "Izbegavanje viška azota.",
                "Izbor tolerantnih sorti."],
         "en": ["Space plants and strip lower leaves so air can flow.",
                "Avoid excess nitrogen.",
                "Choose tolerant varieties."]},
        {"sr": ["Prskanje rastvorom sode bikarbone sa nekoliko kapi biljnog ulja.",
                "Primena dozvoljenog sumpornog preparata, po oblačnom vremenu i ne na vrućini.",
                "Kidanje najzahvaćenijih donjih listova."],
         "en": ["Spray a baking soda solution with a few drops of vegetable oil.",
                "Apply an approved sulphur preparation on a cloudy day, never in heat.",
                "Pull off the worst-affected lower leaves."]},
        [rule("krastavac", "pepelnica", "toplo-uz-suv-list",
              all_of(band(20, 27), rain_at_most(3, 1)), weight=2)]),

    threat("paucinar", "pest",
        {"sr": "Obični paučinar", "en": "Two-spotted spider mite"},
        {"sr": "Sitna grinja na naličju lista; po vrućem i suvom vremenu množi se eksplozivno, list postaje tačkast, sivkast i na kraju se suši.",
         "en": "A tiny mite on the leaf underside; in hot dry weather it multiplies explosively, leaving the leaf stippled, grey and finally dead."},
        {"sr": ["Redovan pregled naličja listova, jer se napad primeti tek kad je odmakao.",
                "Održavanje vlažnosti vazduha oko biljaka u vrhuncu vrućina.",
                "Uklanjanje korova koji su domaćini grinje."],
         "en": ["Check leaf undersides regularly — an attack is usually noticed late.",
                "Keep humidity up around the plants during the hottest spells.",
                "Clear weeds that host the mite."]},
        {"sr": ["Jako orošavanje naličja lista vodom, čime se populacija razbija.",
                "Preparati na bazi biljnih ulja ili kalijumovog sapuna.",
                "Uklanjanje i uništavanje najjače napadnutih listova."],
         "en": ["Hose the leaf undersides hard with water to break up the population.",
                "Use plant-oil or potassium-soap preparations.",
                "Remove and destroy the worst-affected leaves."]},
        [rule("krastavac", "paucinar", "vrucina-i-suv-vazduh",
              all_of(temp_above(27), dry_air(40))),
         rule("krastavac", "paucinar", "susa", rain_at_most(5, 1))]),

    threat("gorcina-ploda", "other",
        {"sr": "Gorčina ploda", "en": "Fruit bitterness"},
        {"sr": "Pri vrućini i nedostatku vode biljka stvara kukurbitacine i plod postaje gorak. Nije bolest, ne prenosi se i ne leči se prskanjem.",
         "en": "In heat and water shortage the plant produces cucurbitacins and the fruit turns bitter. It is not a disease, does not spread, and no spray will fix it."},
        {"sr": ["Redovno zalivanje bez sušnih prekida.",
                "Malčiranje i senčenje u najtoplijim danima."],
         "en": ["Water regularly with no dry gaps.",
                "Mulch and shade through the hottest days."]},
        {"sr": ["Uspostavljanje redovnog zalivanja.",
                "Češća berba, dok su plodovi mlađi i manji."],
         "en": ["Get back to regular watering.",
                "Pick more often, while the fruit is younger and smaller."]},
        [rule("krastavac", "gorcina-ploda", "vrucina-i-susa",
              all_of(temp_above(30), rain_at_most(4, 2)), weight=2)]),
])

# ---------------------------------------------------------------- kupus
crop("kupus", (4, 11), {"sr": "Kupus", "en": "Cabbage"}, [
    threat("plamenjaca", "fungalDisease",
        {"sr": "Plamenjača kupusa", "en": "Cabbage downy mildew"},
        {"sr": "Žućkaste pege na licu lista sa belom prevlakom na naličju; najopasnija je na rasadu i mladim biljkama po hladnijem vlažnom vremenu.",
         "en": "Yellowish patches on the upper leaf with a white bloom beneath; most dangerous on seedlings and young plants in cool wet weather."},
        {"sr": ["Ne saditi na parcelama gde su prethodne godine bile druge krstašice.",
                "Razmak sadnje koji omogućava provetravanje.",
                "Zalivanje ujutru, da list prenoći suv."],
         "en": ["Do not plant where other brassicas grew last year.",
                "Space plants so air can move through.",
                "Water in the morning so leaves go into the night dry."]},
        {"sr": ["Tretman čajem od kamilice ili rastavića.",
                "Posipanje drvenim pepelom oko biljaka.",
                "Sakupljanje i uništavanje zaraženih listova izvan bašte."],
         "en": ["Treat with chamomile or horsetail tea.",
                "Dust wood ash around the plants.",
                "Collect infected leaves and destroy them away from the garden."]},
        [rule("kupus", "plamenjaca", "uslovi-za-infekciju",
              all_of(band(15, 20), humid_min(60)), weight=2),
         rule("kupus", "plamenjaca", "padavine", rain_at_least(2, 10))]),

    threat("crna-trulez", "other",
        {"sr": "Crna trulež", "en": "Black rot"},
        {"sr": "Bakteriozno oboljenje, ne gljivično — zato bakarni preparati protiv njega slabo pomažu. Daje žute klinaste pege sa poglednutim tamnim nervima, po toplom i kišovitom vremenu.",
         "en": "A bacterial disease, not a fungal one, which is why copper does little against it. It shows as yellow V-shaped patches with blackened veins, in warm rainy weather."},
        {"sr": ["Zdrav, sertifikovan rasad iz proverenog izvora.",
                "Plodored od najmanje četiri godine bez krstašica.",
                "Ne raditi u usevu dok su biljke mokre."],
         "en": ["Healthy certified transplants from a trusted source.",
                "A rotation of at least four years without brassicas.",
                "Never work in the crop while the plants are wet."]},
        {"sr": ["Vađenje i uništavanje obolelih biljaka izvan bašte.",
                "Prekid svih radova u mokrom usevu, jer se bakterija prenosi rukama i alatom.",
                "Poboljšanje drenaže i prestanak zalivanja preko lista."],
         "en": ["Pull and destroy diseased plants away from the garden.",
                "Stop all work in a wet crop — hands and tools carry the bacterium.",
                "Improve drainage and stop watering over the leaves."]},
        [rule("kupus", "crna-trulez", "toplo-i-kisovito",
              all_of(avg_band(25, 30), rain_at_least(3, 15)), weight=2)]),

    threat("kupusar", "pest",
        {"sr": "Kupusar", "en": "Large white butterfly"},
        {"sr": "Gusenice belog leptira izgrizaju listove do nervature i ulaze u glavicu. Leptir najviše leti po toplom i suvom vremenu.",
         "en": "The caterpillars chew leaves down to the veins and bore into the head. The butterfly flies most in warm dry weather."},
        {"sr": ["Mreže protiv insekata preko useva od sadnje.",
                "Redovan pregled naličja listova i uklanjanje legala jaja.",
                "Sadnja mirisnih biljaka koje odbijaju leptira."],
         "en": ["Insect netting over the crop from planting.",
                "Check leaf undersides regularly and remove egg clusters.",
                "Plant aromatic companions that put the butterfly off."]},
        {"sr": ["Ručno sakupljanje gusenica i legala jaja.",
                "Preparati na bazi Bacillus thuringiensis dok su gusenice mlade.",
                "Uklanjanje najjače izgrizanih listova."],
         "en": ["Hand-pick caterpillars and egg clusters.",
                "Use Bacillus thuringiensis while the caterpillars are young.",
                "Remove the worst-chewed leaves."]},
        [rule("kupus", "kupusar", "toplo", avg_band(18, 28)),
         rule("kupus", "kupusar", "suvo", rain_at_most(3, 2))]),

    threat("pucanje-glavica", "other",
        {"sr": "Pucanje glavica", "en": "Head splitting"},
        {"sr": "Obilna kiša posle sušnog perioda naglo puni glavicu vodom i ona puca; kroz pukotinu odmah ulazi trulež.",
         "en": "Heavy rain after a dry spell fills the head with water and it splits; rot enters through the crack immediately."},
        {"sr": ["Ravnomerno zalivanje pred zrenje.",
                "Blagovremena berba zrelih glavica."],
         "en": ["Water evenly as the heads approach maturity.",
                "Cut mature heads promptly."]},
        {"sr": ["Hitna berba zrelih glavica pred najavljenu kišu.",
                "Blago potkidanje korena kod prezrelih glavica, da uspore usvajanje vode."],
         "en": ["Cut mature heads before forecast rain arrives.",
                "Give over-mature heads a slight root twist to slow water uptake."]},
        [rule("kupus", "pucanje-glavica", "pljusak-posle-suse",
              rain_at_least(2, 25), weight=2)]),
])

# ---------------------------------------------------------------- luk
crop("luk", (3, 8), {"sr": "Luk (crni)", "en": "Onion"}, [
    threat("plamenjaca", "fungalDisease",
        {"sr": "Plamenjača luka", "en": "Onion downy mildew"},
        {"sr": "Bledozelene izdužene pege sa ljubičastom prevlakom po vlažnom jutru; list se prelama i lukovica ostaje sitna.",
         "en": "Pale elongated patches with a violet bloom on a damp morning; the leaf folds over and the bulb stays small."},
        {"sr": ["Preventivni bakarni preparati u vlažnim periodima.",
                "Izbegavanje viška azota, koji daje mekan i osetljiv list.",
                "Plodored i uklanjanje samoniklog luka."],
         "en": ["Preventive copper in wet periods.",
                "Avoid excess nitrogen, which gives soft susceptible leaves.",
                "Rotate and remove volunteer onions."]},
        {"sr": ["Hitna primena dozvoljenih bakarnih preparata.",
                "Prskanje čajem od rastavića.",
                "Plitka obrada tla radi razbijanja pokorice i bržeg sušenja."],
         "en": ["Apply approved copper preparations without delay.",
                "Spray with horsetail tea.",
                "Break the soil crust shallowly so the ground dries faster."]},
        [rule("luk", "plamenjaca", "uslovi-za-infekciju",
              all_of(band(15, 20), humid_min(60)), weight=2),
         rule("luk", "plamenjaca", "padavine", rain_at_least(3, 10))]),

    threat("purpurna-pegavost", "fungalDisease",
        {"sr": "Purpurna pegavost", "en": "Purple blotch"},
        {"sr": "Ovalne pege sa purpurnim centrom na starijem lišću; javlja se u toplijem delu sezone, često posle oštećenja od plamenjače ili tripsa.",
         "en": "Oval spots with a purple centre on older leaves, appearing in the warmer part of the season, often after damage from mildew or thrips."},
        {"sr": ["Uklanjanje starijeg oštećenog lišća.",
                "Plodored i duboko zaoravanje ostataka.",
                "Suzbijanje tripsa, čije rane otvaraju put gljivi."],
         "en": ["Remove older damaged leaves.",
                "Rotate and plough residues in deeply.",
                "Control thrips, whose wounds let the fungus in."]},
        {"sr": ["Tretman dozvoljenim bakarnim preparatom.",
                "Uklanjanje jako zahvaćenog lišća.",
                "Prekid zalivanja preko lista."],
         "en": ["Treat with an approved copper preparation.",
                "Strip badly affected leaves.",
                "Stop watering over the foliage."]},
        [rule("luk", "purpurna-pegavost", "uslovi-za-infekciju",
              all_of(avg_band(22, 30), humid_min(55)), weight=2)]),

    threat("lukova-muva", "pest",
        {"sr": "Lukova muva", "en": "Onion fly"},
        {"sr": "Larve buše lukovicu, biljka žuti i vene, a lukovica trune. Prvi let je u proleće, pri umerenim temperaturama i vlažnom zemljištu.",
         "en": "Larvae bore into the bulb, the plant yellows and wilts, and the bulb rots. The first flight is in spring, at mild temperatures with damp soil."},
        {"sr": ["Mreže protiv insekata odmah posle setve.",
                "Plodored i udaljenost od prošlogodišnje parcele.",
                "Izbegavanje svežeg stajnjaka, koji privlači muvu."],
         "en": ["Insect netting immediately after sowing.",
                "Rotate and keep distance from last year's plot.",
                "Avoid fresh manure, which attracts the fly."]},
        {"sr": ["Vađenje i uništavanje napadnutih biljaka zajedno sa larvama.",
                "Posipanje drvenim pepelom ili kamenim brašnom oko biljaka.",
                "Zalivanje rastvorom entomopatogenih nematoda."],
         "en": ["Pull and destroy attacked plants together with the larvae.",
                "Dust wood ash or rock flour around the plants.",
                "Drench with entomopathogenic nematodes."]},
        [rule("luk", "lukova-muva", "uslovi-za-let",
              all_of(avg_band(12, 22), humid_max(80)), weight=2)]),

    threat("trulez-od-prevlazenosti", "other",
        {"sr": "Trulež usled prevlaženosti", "en": "Waterlogging rot"},
        {"sr": "Dugotrajno zadržavanje vode oko lukovice izaziva trulež i sprečava sazrevanje. Problem je u zemljištu i drenaži, ne u patogenu.",
         "en": "Water standing around the bulb for long causes rot and stops it ripening. The problem is the soil and its drainage, not a pathogen."},
        {"sr": ["Sadnja na izdignute gredice na težim zemljištima.",
                "Prekid zalivanja pred kraj vegetacije."],
         "en": ["Plant on raised beds on heavy soils.",
                "Stop watering towards the end of the season."]},
        {"sr": ["Hitno odvođenje viška vode plitkim kanalićima.",
                "Potpuni prekid zalivanja.",
                "Vađenje luka čim vreme dozvoli i sušenje u tankom sloju, na promaji."],
         "en": ["Drain the excess away through shallow channels at once.",
                "Stop watering entirely.",
                "Lift the onions as soon as weather allows and dry them thinly, in a draught."]},
        [rule("luk", "trulez-od-prevlazenosti", "dugotrajne-padavine",
              rain_at_least(5, 40), weight=2)]),
])

# ---------------------------------------------------------------- emit
def build(lang):
    crops = []
    for c in CROPS:
        crops.append({
            "id": c["id"],
            "name": c["names"][lang],
            "season": {"fromMonth": c["season"][0], "toMonth": c["season"][1]},
            "threats": [{
                "id": t["id"],
                "type": t["type"],
                "name": t["names"][lang],
                "description": t["descriptions"][lang],
                "prevention": t["prevention"][lang],
                "response": t["response"][lang],
                "rules": t["rules"],
            } for t in c["threats"]],
        })
    return {"version": 1, "locale": lang, "crops": crops}

base = "/home/laban/Desktop/Personal/crop-alerts/assets/content"
for lang in ("sr", "en"):
    with open(f"{base}/crops_{lang}.json", "w", encoding="utf-8") as f:
        json.dump(build(lang), f, ensure_ascii=False, indent=2)
        f.write("\n")

total_threats = sum(len(c["threats"]) for c in CROPS)
total_rules = sum(len(t["rules"]) for c in CROPS for t in c["threats"])
kinds = collections.Counter(t["type"] for c in CROPS for t in c["threats"])
print(f"{len(CROPS)} crops, {total_threats} threats, {total_rules} rules")
print(dict(kinds))
