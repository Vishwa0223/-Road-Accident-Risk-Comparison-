# Road Risk Meter: Road Accident Risk Comparison

**WireWizards Hackathon 2026** · KGiSL Institute of Technology
**Problem Statement:** ECW26045 – Road Accident Risk Comparison
**Team:** CODE BLACK – Vishwa M (Team Leader), Tanishka A

A MATLAB tool that compares accident risk across areas using historical crash records. Every area gets a single **risk score from 0 to 100**, is ranked, and is labelled **High**, **Medium** or **Low**. Results are shown as a ranked bar chart, a results table, and an interactive **Road Risk Meter** app. An Arduino (Tinkercad) simulation shows the same verdict on an LCD and LEDs.

---

## What's in this project

| File | Purpose |
|---|---|
| `roadrisk_dataset.m` | **Main script. Run this.** Loads the data, scores and ranks every area, prints the table, draws the chart, saves the CSV and opens the app |
| `riskMeterApp.m` | The interactive Road Risk Meter window (called automatically by the main script) |
| `dataset1.csv` | Crash records used as input (keep it in the same folder) |
| `risk_ranking.csv` | Output: the full ranking of all areas (created when you run the script) |

---

## Requirements

- MATLAB (developed and run in **R2026b**). The app uses `uifigure`, `uigauge`, `uilamp`, `uidropdown` and `uieditfield`, so you need a release that includes these components.
- No extra toolboxes should be needed.
- Internet is needed only for the optional Coimbatore rainfall download (see *Optional modes*).

---

## How to run

1. Put `roadrisk_dataset.m`, `riskMeterApp.m` and `dataset1.csv` in the **same folder** and make it MATLAB's current folder.
2. Open `roadrisk_dataset.m` and press **Run** (no arguments).
3. You will get:
   - a results table in the Command Window (top `topN` areas),
   - a ranked bar chart,
   - `risk_ranking.csv` with every area,
   - the **Road Risk Meter** window.

> Do not paste `riskMeterApp.m` code into `roadrisk_dataset.m`. They must stay as two separate files, otherwise MATLAB reports "requires more input arguments".

---

## How the risk score works

For each area (crashes from `yearRange`, default 2021–2025):

| Weight | Factor | How it is measured |
|---|---|---|
| **65%** | Crash frequency | Weighted crashes per year: fatal = 5, serious = 3, slight = 1 |
| **20%** | Darkness | % of crashes in poor or no lighting (light condition codes 4–7) |
| **15%** | Rain | % of crashes in rain (weather codes 2 and 5) |

Each factor is rescaled to 0–1 across all areas, then:

```
Score = 100 × (0.65 × crash density + 0.20 × darkness + 0.15 × rain)
```

| Score | Level |
|---|---|
| 66–100 | **High** |
| 33–65 | **Medium** |
| 0–32 | **Low** |

Areas with fewer than `minCrashes` (default 30) crashes are ignored. Scores are **relative to the other areas in the dataset**, because each factor is rescaled between the lowest and highest area.

---

## Settings (top of `roadrisk_dataset.m`)

| Setting | Default | Meaning |
|---|---|---|
| `csvFile` | `'dataset1.csv'` | Input file |
| `runMode` | `"hotspots"` | `"hotspots"` ranks areas in the dataset; `"corridors"` ranks Coimbatore roads |
| `groupBy` | `"area"` | `"area"` (cities/councils) or `"road"` (individual roads) |
| `areaName` | `""` | With `groupBy = "road"`, which area's roads to rank (`""` = busiest area) |
| `topN` | `15` | How many areas appear in the chart and table |
| `minCrashes` | `30` | Ignore areas with fewer crashes |
| `weighted` | `true` | Serious and fatal crashes count more |
| `yearRange` | `[2021 2025]` | Years to include |

---

## Road Risk Meter app

- **Gauge and traffic-light lamps** show the score and level for the current area.
- **Stats line:** score, total crashes, fatal crashes, % in the dark, % in rain.
- **View dropdown:** switch between **Top 10 areas** and **All 367 areas**.
- **Search box:** type an area name (full or partial, e.g. `Leeds` or `bir`) and press Enter or **Go**. If several areas match, use **Next / Previous** to browse them.
- **Clear** returns to the dropdown's view.
- **Previous / Next** step through the current list; **Auto-play** cycles every 3 seconds.
- The window size is fixed so the lamps and labels stay aligned.

---

## Example result

| Rank | Area | Score | Level | Crashes | Fatal | % dark | % rain |
|---|---|---|---|---|---|---|---|
| 1 | Birmingham | 83 | High | 11,322 | 112 | 34 | 12 |
| 2 | Leeds | 65 | Medium | 7,298 | 85 | 31 | 12 |
| 3 | Bradford | 53 | Medium | 5,163 | 54 | 32 | 16 |
| 4 | Westminster | 52 | Medium | 5,887 | 19 | 34 | 11 |

---

## Arduino hardware simulation (Tinkercad)

Components: **Arduino UNO**, **16×2 LCD**, **red / yellow / green LEDs**, **push button**. The LCD shows the area name and score with its level (for example `Birmingham` / `Score:83 HIGH`).

*(Add your Arduino sketch and Tinkercad link here.)*

---

## Optional modes

- **Individual roads:** set `groupBy = "road"` and `areaName = "Birmingham"` to rank roads inside one area.
- **Coimbatore corridors:** set `runMode = "corridors"` to score six Coimbatore roads (Avinashi Rd, Trichy Rd, Race Course Rd, Sathy Rd, Mettupalayam Rd, Siruvani Rd). This needs a dataset that covers Coimbatore; the included dataset does not. With `useAPI = true`, rainfall is downloaded from the Open-Meteo API.

---

## Limitations and future work

- The score uses crash counts, severity, lighting and weather. **Traffic volume** and **road geometry** from the problem statement are not yet part of the model and are planned extensions.
- Results depend on the supplied dataset and are relative between areas, not an absolute probability of an accident.
- Area codes are mapped to names using a built-in list; unknown codes appear as `Area <code>`.
