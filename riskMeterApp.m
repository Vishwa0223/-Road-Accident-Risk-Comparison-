function riskMeterApp(Area, Score, Level, Crashes, Fatal, DarkPct, topN, RainPct)
% RISKMETERAPP  Interactive "Road Risk Meter" window (software only, no hardware needed).
%   Gauge + traffic-light lamps + Prev/Next buttons + Auto-play
%   + dropdown to switch between "Top N" and "All areas"
%   + search box: type any area name (full or partial) and its data appears.
%
%   Inputs are the full ranked lists (sorted highest risk first).
%   topN    - how many areas the "Top" view cycles through (default 10)
%   RainPct - optional, % of crashes in rain (shown if supplied)
if nargin < 7 || isempty(topN), topN = 10; end
hasRain = nargin >= 8 && ~isempty(RainPct);

Area = string(Area(:));  Level = string(Level(:));
n = numel(Area);
k = min(topN, n);

active    = 1:k;          % indices (into the full ranking) the buttons cycle through
pos       = 1;            % position inside 'active'
rankTotal = k;            % the "of N" shown in the rank label
matchMode = false;        % true while showing search results
timerObj  = [];

colRed = [0.90 0.15 0.15];  colYel = [0.98 0.80 0.10];  colGrn = [0.15 0.75 0.30];
colOff = [0.30 0.30 0.30];  bg = [0.11 0.14 0.22];

f = uifigure('Name','Road Risk Meter','Position',[200 60 620 650],'Color',bg);

% ---------- search / view controls (top bar) ----------
uilabel(f,'Text','View:','Position',[20 603 40 24],'FontColor','w');
ddView = uidropdown(f,'Position',[62 603 150 26], ...
    'Items',{sprintf('Top %d areas',k), sprintf('All %d areas',n)}, ...
    'ItemsData',{'top','all'},'Value','top', ...
    'ValueChangedFcn',@(~,~) changeView());
uilabel(f,'Text','Search:','Position',[228 603 50 24],'FontColor','w');
edtSearch = uieditfield(f,'text','Position',[282 603 200 26], ...
    'Placeholder','type an area, e.g. Leeds', ...
    'ValueChangedFcn',@(~,~) doSearch());
uibutton(f,'push','Text','Go','Position',[488 603 50 26],'ButtonPushedFcn',@(~,~) doSearch());
uibutton(f,'push','Text','Clear','Position',[544 603 56 26],'ButtonPushedFcn',@(~,~) clearSearch());
lblStatus = uilabel(f,'Position',[20 575 580 22],'HorizontalAlignment','center', ...
    'FontSize',12,'FontColor',[0.6 0.65 0.75],'Text', ...
    sprintf('%d areas available - type a name to look one up.', n));

% ---------- main display (same layout as before) ----------
uilabel(f,'Text','ROAD RISK METER','Position',[0 525 620 40], ...
    'HorizontalAlignment','center','FontSize',26,'FontWeight','bold','FontColor','w');
lblRank = uilabel(f,'Position',[20 490 580 28],'HorizontalAlignment','center', ...
    'FontSize',16,'FontColor',[0.65 0.78 1]);
lblArea = uilabel(f,'Position',[20 435 580 55],'HorizontalAlignment','center', ...
    'FontSize',34,'FontWeight','bold','FontColor','w');

gauge = uigauge(f,'semicircular','Position',[150 270 320 165],'Limits',[0 100]);
gauge.ScaleColors      = {colGrn, colYel, colRed};
gauge.ScaleColorLimits = [0 33; 33 66; 66 100];
gauge.MajorTicks       = [0 33 66 100];

lblLevel = uilabel(f,'Position',[20 220 580 45],'HorizontalAlignment','center', ...
    'FontSize',30,'FontWeight','bold');
lblInfo  = uilabel(f,'Position',[20 180 580 30],'HorizontalAlignment','center', ...
    'FontSize',14,'FontColor',[0.85 0.9 1]);

lampR = uilamp(f,'Position',[200 120 36 36]);  uilabel(f,'Text','High','Position',[190 90 60 22], ...
    'HorizontalAlignment','center','FontColor','w');
lampY = uilamp(f,'Position',[292 120 36 36]);  uilabel(f,'Text','Medium','Position',[282 90 60 22], ...
    'HorizontalAlignment','center','FontColor','w');
lampG = uilamp(f,'Position',[384 120 36 36]);  uilabel(f,'Text','Low','Position',[374 90 60 22], ...
    'HorizontalAlignment','center','FontColor','w');

uibutton(f,'push','Text','< Previous','Position',[120 40 110 32],'ButtonPushedFcn',@(~,~) step(-1));
uibutton(f,'push','Text','Next >','Position',[250 40 110 32],'ButtonPushedFcn',@(~,~) step(1));
uicheckbox(f,'Text','Auto-play','Position',[390 44 110 24],'FontColor','w', ...
    'ValueChangedFcn',@(src,~) autoPlay(src.Value));
uilabel(f,'Text','Score 0-100: the higher the score, the more dangerous the area.', ...
    'Position',[20 8 580 22],'HorizontalAlignment','center','FontSize',12,'FontColor',[0.6 0.65 0.75]);

f.CloseRequestFcn = @(~,~) closeApp();
refresh();

    function refresh()
        i = active(pos);
        s = Score(i);
        if matchMode
            lblRank.Text = sprintf('Rank #%d of %d   (match %d of %d)', i, n, pos, numel(active));
        else
            lblRank.Text = sprintf('Rank #%d of %d', i, rankTotal);
        end
        nm = char(Area(i));
        lblArea.Text = nm;
        lblArea.FontSize = max(14, min(34, floor(560 / (0.6*max(numel(nm),1)))));   % long names shrink to fit
        gauge.Value  = s;
        lampR.Color = colOff;  lampY.Color = colOff;  lampG.Color = colOff;
        switch string(Level(i))
            case "High"
                lampR.Color = colRed;  lblLevel.Text = 'HIGH RISK';   lblLevel.FontColor = colRed;
            case "Medium"
                lampY.Color = colYel;  lblLevel.Text = 'MEDIUM RISK'; lblLevel.FontColor = colYel;
            otherwise
                lampG.Color = colGrn;  lblLevel.Text = 'LOW RISK';    lblLevel.FontColor = colGrn;
        end
        txt = sprintf('Score %d/100  |  %d crashes  |  %d fatal  |  %d%% dark', ...
            s, Crashes(i), Fatal(i), DarkPct(i));
        if hasRain
            txt = sprintf('%s  |  %d%% rain', txt, RainPct(i));
        end
        lblInfo.Text = txt;
    end

    function step(d)
        pos = mod(pos - 1 + d, numel(active)) + 1;
        refresh();
    end

    function changeView()
        % switch between Top-N and All areas (also clears any search)
        edtSearch.Value = '';
        matchMode = false;
        if string(ddView.Value) == "all"
            active = 1:n;  rankTotal = n;
            setStatus(sprintf('Browsing all %d areas, ranked from most to least dangerous.', n), [0.6 0.65 0.75]);
        else
            active = 1:k;  rankTotal = k;
            setStatus(sprintf('Showing the top %d most dangerous areas.', k), [0.6 0.65 0.75]);
        end
        pos = 1;
        refresh();
    end

    function doSearch()
        q = strtrim(string(edtSearch.Value));
        if q == ""
            clearSearch();  return;
        end
        low = lower(Area);
        ql  = lower(q);
        hit = find(low == ql);                 % exact name first
        if isempty(hit)
            hit = find(contains(low, ql));     % otherwise partial matches
        end
        if isempty(hit)
            setStatus(sprintf('No area found matching "%s". Check the spelling.', q), colRed);
            return;
        end
        active = hit(:)';
        pos = 1;
        matchMode = true;
        if numel(active) == 1
            setStatus(sprintf('Showing "%s".', Area(active)), colGrn);
        else
            setStatus(sprintf('%d areas match "%s" - use Next / Previous to browse them.', numel(active), q), colYel);
        end
        refresh();
    end

    function clearSearch()
        edtSearch.Value = '';
        changeView();      % go back to whichever view the dropdown shows
    end

    function setStatus(msg, col)
        lblStatus.Text = msg;
        lblStatus.FontColor = col;
    end

    function autoPlay(on)
        stopTimer();
        if on
            timerObj = timer('ExecutionMode','fixedSpacing','Period',3, ...
                'TimerFcn',@(~,~) step(1));
            start(timerObj);
        end
    end

    function stopTimer()
        if ~isempty(timerObj) && isvalid(timerObj)
            stop(timerObj);  delete(timerObj);
        end
        timerObj = [];
    end

    function closeApp()
        stopTimer();
        delete(f);
    end
end
