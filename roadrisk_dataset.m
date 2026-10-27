%% ROAD ACCIDENT RISK - which areas are the most dangerous?
%  Reads your crash dataset (dataset1.csv), scores every area from 0 to 100,
%  and shows a ranked chart + table.  Just press RUN.
%
%  HOW THE SCORE WORKS (same idea as the original code)
%     65%  how many crashes happen there (fatal = 5x, serious = 3x, slight = 1x)
%     20%  how many of those crashes happen in the dark
%     15%  how many of those crashes happen in the rain
%  Score 66-100 = HIGH risk | 33-65 = MEDIUM risk | 0-32 = LOW risk
clear; clc; close all;

%% ===================== SETTINGS (change these if you like) =====================
csvFile    = 'dataset1.csv';  % keep this file in MATLAB's current folder (or give the full path)
runMode    = "hotspots";      % "hotspots"  = rank the areas found in the dataset
                              % "corridors" = rank YOUR Coimbatore roads (needs a Coimbatore dataset)
groupBy    = "area";          % hotspots only: "area" (cities / councils)  or  "road" (individual roads)
areaName   = "";              % only used with groupBy = "road": e.g. "Birmingham" ("" = busiest area)
topN       = 15;              % how many areas to show in the chart
minCrashes = 30;              % ignore areas with fewer crashes than this
weighted   = true;            % true = serious/fatal crashes count more
yearRange  = [2021 2025];     % which years to include
radiusKm   = 2;               % corridors only: crashes within this distance count for a road
useAPI     = true;            % corridors only: download rainfall from Open-Meteo


%% ===================== LOAD DATA =====================
keep = ["collision_year","longitude","latitude","collision_severity", ...
        "light_conditions","weather_conditions","local_authority_ons_district", ...
        "first_road_class","first_road_number"];
opts = detectImportOptions(csvFile);
opts.SelectedVariableNames = keep;
opts = setvartype(opts, keep(keep ~= "local_authority_ons_district"), "double");
opts = setvartype(opts, "local_authority_ons_district", "string");
T = readtable(csvFile, opts);
T = T(T.collision_year >= yearRange(1) & T.collision_year <= yearRange(2), :);
nYears = yearRange(2) - yearRange(1) + 1;
fprintf('Loaded %d crash records (%d to %d).\n', height(T), yearRange(1), yearRange(2));

% turn the official area codes (like E08000025) into real names (like Birmingham)
[codeList, nameList] = areaNames();
[tf, loc] = ismember(T.local_authority_ons_district, codeList);
T.areaLabel = "Area " + T.local_authority_ons_district;      % fallback if a code is unknown
T.areaLabel(tf) = nameList(loc(tf));

%% ===================== DEFINE THE AREAS TO COMPARE =====================
lengthKm = [];  litFlag = [];  rainAPI = [];
if runMode == "hotspots"
    if groupBy == "area"
        area = T.areaLabel;
        tag  = 'by area';
    else
        if areaName == ""
            [g0, n0] = findgroups(T.areaLabel);
            [~, imax] = max(accumarray(g0, 1));
            areaName = n0(imax);
        end
        inArea = lower(T.areaLabel) == lower(areaName);
        if ~any(inArea), error('Area "%s" not found. Check the spelling (e.g. "Leeds", "Glasgow City").', areaName); end
        T = T(inArea & T.first_road_number > 0, :);
        classes = ["M";"A(M)";"A";"B";"C";"U"];
        rc  = T.first_road_class;
        cls = repmat("?", height(T), 1);
        ok  = rc >= 1 & rc <= 6;
        cls(ok) = classes(rc(ok));
        area = cls + string(T.first_road_number);            % e.g. A38, M6, B4100
        tag  = ['- roads in ' char(areaName)];
    end
else
    % ---- your Coimbatore roads ----
    cArea = ["Avinashi Rd";"Trichy Rd";"Race Course Rd";"Sathy Rd";"Mettupalayam Rd";"Siruvani Rd"];
    cLat  = [11.026; 10.999; 10.998; 11.080; 11.075; 10.974];
    cLon  = [77.000; 77.036; 76.976; 76.990; 76.950; 76.912];
    cLen  = [8; 7; 3; 9; 8; 12];
    cLit  = [1; 1; 1; 0; 0; 0];

    T = T(~isnan(T.latitude) & ~isnan(T.longitude), :);
    D = zeros(height(T), numel(cArea));
    for j = 1:numel(cArea)
        D(:,j) = hav(cLat(j), cLon(j), T.latitude, T.longitude);
    end
    [dmin, jn] = min(D, [], 2);
    hit = dmin <= radiusKm;
    if ~any(hit)
        error(['No crashes within %.1f km of your Coimbatore roads. This dataset only covers ' ...
               'latitude %.1f to %.1f and longitude %.1f to %.1f (it is not Coimbatore data). ' ...
               'Use a Coimbatore dataset, or set runMode = "hotspots".'], ...
               radiusKm, min(T.latitude), max(T.latitude), min(T.longitude), max(T.longitude));
    end
    T = T(hit, :);
    area = cArea(jn(hit));
    tag  = '- Coimbatore roads';
    if useAPI
        rainAPI = nan(numel(cArea),1);
        for i = 1:numel(cArea)
            try
                w = webread("https://archive-api.open-meteo.com/v1/archive", ...
                    "latitude", cLat(i), "longitude", cLon(i), ...
                    "start_date", "2023-01-01", "end_date", "2025-12-31", ...
                    "daily", "precipitation_sum", "timezone", "auto", weboptions('Timeout',60));
                rainAPI(i) = 100 * mean(w.daily.precipitation_sum > 1, 'omitnan');
            catch
            end
            pause(0.3);
        end
    end
end

% remove areas with too few crashes (hotspots mode)
[g, names] = findgroups(area);
if runMode == "hotspots"
    cnt  = accumarray(g, 1);
    good = ismember(area, names(cnt >= minCrashes));
    T = T(good, :);  area = area(good);
    if isempty(T), error('No area has at least %d crashes. Lower minCrashes.', minCrashes); end
    [g, names] = findgroups(area);
end
n = numel(names);

%% ===================== MEASURE EACH AREA =====================
w = ones(height(T), 1);
if weighted
    w(T.collision_severity == 1) = 5;      % fatal
    w(T.collision_severity == 2) = 3;      % serious
end
crashes = accumarray(g, 1);
wsum    = accumarray(g, w);
fatal   = accumarray(g, double(T.collision_severity == 1));

validLight = T.light_conditions   > 0;   isDark = ismember(T.light_conditions,   [4 5 6 7]);
validWeath = T.weather_conditions > 0;   isRain = ismember(T.weather_conditions, [2 5]);
darkPct = 100 * accumarray(g, double(isDark & validLight)) ./ max(accumarray(g, double(validLight)), 1);
rain    = 100 * accumarray(g, double(isRain & validWeath)) ./ max(accumarray(g, double(validWeath)), 1);

if runMode == "corridors"
    [~, locC] = ismember(names, cArea);
    density  = wsum ./ cLen(locC) ./ nYears;        % crashes per km per year
    if useAPI
        r = rainAPI(locC);
        r(isnan(r)) = median(rainAPI, 'omitnan');
        if all(isnan(r)), r(:) = 15; end             % offline fallback
        rain = r;
    end
    darkness = 1 - cLit(locC);                       % unlit road = more risk
else
    density  = wsum ./ nYears;                       % crashes per year
    darkness = nrm(darkPct);
end

%% ===================== RISK SCORE (0-100) =====================
score = 100 * (0.65*nrm(density) + 0.20*darkness + 0.15*nrm(rain));
level = repmat("Low", n, 1);
level(score >= 33) = "Medium";
level(score >= 66) = "High";

%% ===================== RESULTS TABLE =====================
[~, order] = sort(score, 'descend');
Rank              = (1:n)';
Area              = names(order);
Total_Crashes     = crashes(order);
Fatal_Crashes     = fatal(order);
Crashes_In_Dark_Pct = round(darkPct(order));
Crashes_In_Rain_Pct = round(rain(order));
Risk_Score        = round(score(order));
Risk_Level        = level(order);
R = table(Rank, Area, Total_Crashes, Fatal_Crashes, Crashes_In_Dark_Pct, ...
          Crashes_In_Rain_Pct, Risk_Score, Risk_Level);
try   % friendlier column headings (needs MATLAB R2019b or newer)
    R.Properties.VariableNames = {'Rank','Area','Total crashes','Fatal crashes', ...
        '% in the dark','% in rain','Risk score (0-100)','Risk level'};
catch
    R.Properties.VariableNames = {'Rank','Area','Total_crashes','Fatal_crashes', ...
        'Pct_in_dark','Pct_in_rain','Risk_score','Risk_level'};
end

fprintf('\n================ RESULT ================\n');
fprintf('Highest-risk place: %s\n', Area(1));
fprintf('   Risk score %d/100 (%s) | %d crashes | %d fatal | %d%% happened in the dark\n', ...
        Risk_Score(1), upper(Risk_Level(1)), Total_Crashes(1), Fatal_Crashes(1), Crashes_In_Dark_Pct(1));
fprintf('Places rated HIGH: %d | MEDIUM: %d | LOW: %d  (out of %d compared)\n', ...
        sum(level=="High"), sum(level=="Medium"), sum(level=="Low"), n);
fprintf('========================================\n\n');
disp(R(1:min(topN,n), :));
writetable(R, 'risk_ranking.csv');
fprintf('Full ranking of all %d places saved to risk_ranking.csv\n', n);

%% ===================== CHART =====================
m = min(topN, n);
fig = figure('Color','w','Position',[100 100 1050 650]);
try, theme(fig,"light"); catch, end
ax = axes(fig);  hold(ax,'on');
cHigh = [0.85 0.20 0.20];  cMed = [0.95 0.70 0.20];  cLow = [0.20 0.70 0.30];
b = barh(ax, 1:m, Risk_Score(1:m), 0.72, 'FaceColor', 'flat');
for k = 1:m
    switch Risk_Level(k)
        case "High",   b.CData(k,:) = cHigh;
        case "Medium", b.CData(k,:) = cMed;
        otherwise,     b.CData(k,:) = cLow;
    end
    text(ax, Risk_Score(k) + 1, k, sprintf('%d', Risk_Score(k)), ...
         'VerticalAlignment','middle','FontWeight','bold','Color','k');
end
set(ax, 'YDir','reverse', 'YTick',1:m, 'YTickLabel',cellstr(Area(1:m)), ...
        'TickLabelInterpreter','none', 'FontSize',11, ...
        'Color','w', 'XColor','k', 'YColor','k', 'GridColor',[0.6 0.6 0.6]);
xlim(ax, [0 108]);  grid(ax,'on');  box(ax,'off');
xlabel(ax, 'Risk score   (0 = lowest risk,  100 = highest risk)', 'Color','k');
title(ax, ['Most dangerous places for road accidents ' tag], 'Color','k', 'FontSize',15);
subtitle(ax, sprintf('Based on crash records %d-%d: how many crashes, how serious, and how many in the dark / rain', ...
                     yearRange(1), yearRange(2)), 'Color',[0.35 0.35 0.35]);
h1 = patch(ax, NaN, NaN, cHigh);  h2 = patch(ax, NaN, NaN, cMed);  h3 = patch(ax, NaN, NaN, cLow);
lg = legend(ax, [h1 h2 h3], {'High risk (66-100)','Medium risk (33-65)','Low risk (0-32)'}, ...
            'Location','southeast');
try, lg.TextColor = 'k'; lg.Color = 'w'; catch, end

%% ===================== INTERACTIVE RISK METER WINDOW =====================
riskMeterApp(Area, Risk_Score, Risk_Level, Total_Crashes, Fatal_Crashes, Crashes_In_Dark_Pct, 10, Crashes_In_Rain_Pct);
%% ===================== LOCAL FUNCTIONS =====================
function v = nrm(v)                                   % rescale values to 0..1
    v = (v - min(v)) ./ max(max(v) - min(v), eps);
end

function d = hav(lat1, lon1, lat2, lon2)              % distance in km between points
    a = sind((lat2-lat1)/2).^2 + cosd(lat1).*cosd(lat2).*sind((lon2-lon1)/2).^2;
    d = 6371 * 2 * asin(sqrt(a));
end

function [codes, names] = areaNames()                 % official area code -> area name
    P = [
    "E06000001","Hartlepool";
    "E06000002","Middlesbrough";
    "E06000003","Redcar and Cleveland";
    "E06000004","Stockton-on-Tees";
    "E06000005","Darlington";
    "E06000006","Halton";
    "E06000007","Warrington";
    "E06000008","Blackburn with Darwen";
    "E06000009","Blackpool";
    "E06000010","Kingston upon Hull";
    "E06000011","East Riding of Yorkshire";
    "E06000012","North East Lincolnshire";
    "E06000013","North Lincolnshire";
    "E06000014","York";
    "E06000015","Derby";
    "E06000016","Leicester";
    "E06000017","Rutland";
    "E06000018","Nottingham";
    "E06000019","Herefordshire";
    "E06000020","Telford and Wrekin";
    "E06000021","Stoke-on-Trent";
    "E06000022","Bath and North East Somerset";
    "E06000023","Bristol";
    "E06000024","North Somerset";
    "E06000025","South Gloucestershire";
    "E06000026","Plymouth";
    "E06000027","Torbay";
    "E06000030","Swindon";
    "E06000031","Peterborough";
    "E06000032","Luton";
    "E06000033","Southend-on-Sea";
    "E06000034","Thurrock";
    "E06000035","Medway";
    "E06000036","Bracknell Forest";
    "E06000037","West Berkshire";
    "E06000038","Reading";
    "E06000039","Slough";
    "E06000040","Windsor and Maidenhead";
    "E06000041","Wokingham";
    "E06000042","Milton Keynes";
    "E06000043","Brighton and Hove";
    "E06000044","Portsmouth";
    "E06000045","Southampton";
    "E06000046","Isle of Wight";
    "E06000047","County Durham";
    "E06000049","Cheshire East";
    "E06000050","Cheshire West and Chester";
    "E06000051","Shropshire";
    "E06000052","Cornwall";
    "E06000053","Isles of Scilly";
    "E06000054","Wiltshire";
    "E06000055","Bedford";
    "E06000056","Central Bedfordshire";
    "E06000057","Northumberland";
    "E06000058","Bournemouth, Christchurch and Poole";
    "E06000059","Dorset";
    "E06000060","Buckinghamshire";
    "E06000061","North Northamptonshire";
    "E06000062","West Northamptonshire";
    "E06000063","Cumberland";
    "E06000064","Westmorland and Furness";
    "E06000065","North Yorkshire";
    "E06000066","Somerset";
    "E07000008","Cambridge";
    "E07000009","East Cambridgeshire";
    "E07000010","Fenland";
    "E07000011","Huntingdonshire";
    "E07000012","South Cambridgeshire";
    "E07000026","Allerdale";
    "E07000027","Barrow-in-Furness";
    "E07000028","Carlisle";
    "E07000029","Copeland";
    "E07000030","Eden";
    "E07000031","South Lakeland";
    "E07000032","Amber Valley";
    "E07000033","Bolsover";
    "E07000034","Chesterfield";
    "E07000035","Derbyshire Dales";
    "E07000036","Erewash";
    "E07000037","High Peak";
    "E07000038","North East Derbyshire";
    "E07000039","South Derbyshire";
    "E07000040","East Devon";
    "E07000041","Exeter";
    "E07000042","Mid Devon";
    "E07000043","North Devon";
    "E07000044","South Hams";
    "E07000045","Teignbridge";
    "E07000046","Torridge";
    "E07000047","West Devon";
    "E07000061","Eastbourne";
    "E07000062","Hastings";
    "E07000063","Lewes";
    "E07000064","Rother";
    "E07000065","Wealden";
    "E07000066","Basildon";
    "E07000067","Braintree";
    "E07000068","Brentwood";
    "E07000069","Castle Point";
    "E07000070","Chelmsford";
    "E07000071","Colchester";
    "E07000072","Epping Forest";
    "E07000073","Harlow";
    "E07000074","Maldon";
    "E07000075","Rochford";
    "E07000076","Tendring";
    "E07000077","Uttlesford";
    "E07000078","Cheltenham";
    "E07000079","Cotswold";
    "E07000080","Forest of Dean";
    "E07000081","Gloucester";
    "E07000082","Stroud";
    "E07000083","Tewkesbury";
    "E07000084","Basingstoke and Deane";
    "E07000085","East Hampshire";
    "E07000086","Eastleigh";
    "E07000087","Fareham";
    "E07000088","Gosport";
    "E07000089","Hart";
    "E07000090","Havant";
    "E07000091","New Forest";
    "E07000092","Rushmoor";
    "E07000093","Test Valley";
    "E07000094","Winchester";
    "E07000095","Broxbourne";
    "E07000096","Dacorum";
    "E07000098","Hertsmere";
    "E07000099","North Hertfordshire";
    "E07000102","Three Rivers";
    "E07000103","Watford";
    "E07000105","Ashford";
    "E07000106","Canterbury";
    "E07000107","Dartford";
    "E07000108","Dover";
    "E07000109","Gravesham";
    "E07000110","Maidstone";
    "E07000111","Sevenoaks";
    "E07000112","Folkestone and Hythe";
    "E07000113","Swale";
    "E07000114","Thanet";
    "E07000115","Tonbridge and Malling";
    "E07000116","Tunbridge Wells";
    "E07000117","Burnley";
    "E07000118","Chorley";
    "E07000119","Fylde";
    "E07000120","Hyndburn";
    "E07000121","Lancaster";
    "E07000122","Pendle";
    "E07000123","Preston";
    "E07000124","Ribble Valley";
    "E07000125","Rossendale";
    "E07000126","South Ribble";
    "E07000127","West Lancashire";
    "E07000128","Wyre";
    "E07000129","Blaby";
    "E07000130","Charnwood";
    "E07000131","Harborough";
    "E07000132","Hinckley and Bosworth";
    "E07000133","Melton";
    "E07000134","North West Leicestershire";
    "E07000135","Oadby and Wigston";
    "E07000136","Boston";
    "E07000137","East Lindsey";
    "E07000138","Lincoln";
    "E07000139","North Kesteven";
    "E07000140","South Holland";
    "E07000141","South Kesteven";
    "E07000142","West Lindsey";
    "E07000143","Breckland";
    "E07000144","Broadland";
    "E07000145","Great Yarmouth";
    "E07000146","King's Lynn and West Norfolk";
    "E07000147","North Norfolk";
    "E07000148","Norwich";
    "E07000149","South Norfolk";
    "E07000163","Craven";
    "E07000164","Hambleton";
    "E07000165","Harrogate";
    "E07000166","Richmondshire";
    "E07000167","Ryedale";
    "E07000168","Scarborough";
    "E07000169","Selby";
    "E07000170","Ashfield";
    "E07000171","Bassetlaw";
    "E07000172","Broxtowe";
    "E07000173","Gedling";
    "E07000174","Mansfield";
    "E07000175","Newark and Sherwood";
    "E07000176","Rushcliffe";
    "E07000177","Cherwell";
    "E07000178","Oxford";
    "E07000179","South Oxfordshire";
    "E07000180","Vale of White Horse";
    "E07000181","West Oxfordshire";
    "E07000187","Mendip";
    "E07000188","Sedgemoor";
    "E07000189","South Somerset";
    "E07000192","Cannock Chase";
    "E07000193","East Staffordshire";
    "E07000194","Lichfield";
    "E07000195","Newcastle-under-Lyme";
    "E07000196","South Staffordshire";
    "E07000197","Stafford";
    "E07000198","Staffordshire Moorlands";
    "E07000199","Tamworth";
    "E07000200","Babergh";
    "E07000202","Ipswich";
    "E07000203","Mid Suffolk";
    "E07000207","Elmbridge";
    "E07000208","Epsom and Ewell";
    "E07000209","Guildford";
    "E07000210","Mole Valley";
    "E07000211","Reigate and Banstead";
    "E07000212","Runnymede";
    "E07000213","Spelthorne";
    "E07000214","Surrey Heath";
    "E07000215","Tandridge";
    "E07000216","Waverley";
    "E07000217","Woking";
    "E07000218","North Warwickshire";
    "E07000219","Nuneaton and Bedworth";
    "E07000220","Rugby";
    "E07000221","Stratford-on-Avon";
    "E07000222","Warwick";
    "E07000223","Adur";
    "E07000224","Arun";
    "E07000225","Chichester";
    "E07000226","Crawley";
    "E07000227","Horsham";
    "E07000228","Mid Sussex";
    "E07000229","Worthing";
    "E07000234","Bromsgrove";
    "E07000235","Malvern Hills";
    "E07000236","Redditch";
    "E07000237","Worcester";
    "E07000238","Wychavon";
    "E07000239","Wyre Forest";
    "E07000240","St Albans";
    "E07000241","Welwyn Hatfield";
    "E07000242","East Hertfordshire";
    "E07000243","Stevenage";
    "E07000244","East Suffolk";
    "E07000245","West Suffolk";
    "E07000246","Somerset West and Taunton";
    "E08000001","Bolton";
    "E08000002","Bury";
    "E08000003","Manchester";
    "E08000004","Oldham";
    "E08000005","Rochdale";
    "E08000006","Salford";
    "E08000007","Stockport";
    "E08000008","Tameside";
    "E08000009","Trafford";
    "E08000010","Wigan";
    "E08000011","Knowsley";
    "E08000012","Liverpool";
    "E08000013","St. Helens";
    "E08000014","Sefton";
    "E08000015","Wirral";
    "E08000016","Barnsley";
    "E08000017","Doncaster";
    "E08000018","Rotherham";
    "E08000019","Sheffield";
    "E08000021","Newcastle upon Tyne";
    "E08000022","North Tyneside";
    "E08000023","South Tyneside";
    "E08000024","Sunderland";
    "E08000025","Birmingham";
    "E08000026","Coventry";
    "E08000027","Dudley";
    "E08000028","Sandwell";
    "E08000029","Solihull";
    "E08000030","Walsall";
    "E08000031","Wolverhampton";
    "E08000032","Bradford";
    "E08000033","Calderdale";
    "E08000034","Kirklees";
    "E08000035","Leeds";
    "E08000036","Wakefield";
    "E08000037","Gateshead";
    "E08000038","Barnsley";
    "E08000039","Sheffield";
    "E09000001","City of London";
    "E09000002","Barking and Dagenham";
    "E09000003","Barnet";
    "E09000004","Bexley";
    "E09000005","Brent";
    "E09000006","Bromley";
    "E09000007","Camden";
    "E09000008","Croydon";
    "E09000009","Ealing";
    "E09000010","Enfield";
    "E09000011","Greenwich";
    "E09000012","Hackney";
    "E09000013","Hammersmith and Fulham";
    "E09000014","Haringey";
    "E09000015","Harrow";
    "E09000016","Havering";
    "E09000017","Hillingdon";
    "E09000018","Hounslow";
    "E09000019","Islington";
    "E09000020","Kensington and Chelsea";
    "E09000021","Kingston upon Thames";
    "E09000022","Lambeth";
    "E09000023","Lewisham";
    "E09000024","Merton";
    "E09000025","Newham";
    "E09000026","Redbridge";
    "E09000027","Richmond upon Thames";
    "E09000028","Southwark";
    "E09000029","Sutton";
    "E09000030","Tower Hamlets";
    "E09000031","Waltham Forest";
    "E09000032","Wandsworth";
    "E09000033","Westminster";
    "EHEATHROW","Heathrow Airport";
    "S12000005","Clackmannanshire";
    "S12000006","Dumfries and Galloway";
    "S12000008","East Ayrshire";
    "S12000010","East Lothian";
    "S12000011","East Renfrewshire";
    "S12000013","Na h-Eileanan Siar (Western Isles)";
    "S12000014","Falkirk";
    "S12000017","Highland";
    "S12000018","Inverclyde";
    "S12000019","Midlothian";
    "S12000020","Moray";
    "S12000021","North Ayrshire";
    "S12000023","Orkney Islands";
    "S12000026","Scottish Borders";
    "S12000027","Shetland Islands";
    "S12000028","South Ayrshire";
    "S12000029","South Lanarkshire";
    "S12000030","Stirling";
    "S12000033","Aberdeen City";
    "S12000034","Aberdeenshire";
    "S12000035","Argyll and Bute";
    "S12000036","City of Edinburgh";
    "S12000038","Renfrewshire";
    "S12000039","West Dunbartonshire";
    "S12000040","West Lothian";
    "S12000041","Angus";
    "S12000042","Dundee City";
    "S12000045","East Dunbartonshire";
    "S12000047","Fife";
    "S12000048","Perth and Kinross";
    "S12000049","Glasgow City";
    "S12000050","North Lanarkshire";
    "W06000001","Isle of Anglesey";
    "W06000002","Gwynedd";
    "W06000003","Conwy";
    "W06000004","Denbighshire";
    "W06000005","Flintshire";
    "W06000006","Wrexham";
    "W06000008","Ceredigion";
    "W06000009","Pembrokeshire";
    "W06000010","Carmarthenshire";
    "W06000011","Swansea";
    "W06000012","Neath Port Talbot";
    "W06000013","Bridgend";
    "W06000014","Vale of Glamorgan";
    "W06000015","Cardiff";
    "W06000016","Rhondda Cynon Taf";
    "W06000018","Caerphilly";
    "W06000019","Blaenau Gwent";
    "W06000020","Torfaen";
    "W06000021","Monmouthshire";
    "W06000022","Newport";
    "W06000023","Powys";
    "W06000024","Merthyr Tydfil";
    ];
    codes = P(:,1);
    names = P(:,2);
end