# Data Analysis Portfolio

Welcome to my data analysis portfolio.  
This repository highlights projects across **Python, SQL, and Excel** that demonstrate my ability to ingest messy data, clean and normalize it, perform quantitative analysis, and deliver clear, decision-ready outputs.

Each project simulates real-world analytical workflows with **public data (Census, EIA)** or **realistic datasets** and shows the full pipeline: **data ingestion → transformation → tiering/aggregation → visualization/export**.
Note, these project samples are modified/adapted accordingly to exclude sensitive, classified data from the actual projects completed at my job.

---




---

## 🔹 Python Projects

### 1. SLTT Risk Tiering (Real Data)
**File**: `notebooks/sltt_risk_tiering_realdata.ipynb`  
**Skills**: API ingestion, key normalization, dataset merging, quantile tiering, visualization with Matplotlib.  

**Workflow**:
- Import incident counts by county from CSV (e.g., FBI CDE exports).  
- Pull population by county using the **Census ACS API**.  
- Normalize state/county names, merge, and calculate `incidents per 100k`.  
- Assign quartile-based risk tiers.  
- Export clean CSVs and visualize **top/bottom counties**.

---

### 2. Energy Supply Sankey (EIA API)
**File**: `notebooks/eia_energy_sankey.ipynb`  
**Skills**: API requests, data reshaping, Sankey edge construction, interactive Plotly visualization.  

**Workflow**:
- Fetch state-level **electricity generation by fuel type** and **sales by sector** from the **EIA API**.  
- Allocate generation across end-use sectors proportional to sales.  
- Build an interactive **Sankey diagram**: *Fuel → State → Sector*.  
- Export to standalone HTML for sharing or embedding.

---

## 🔹 SQL Projects

### 3. SLTT Tiering with Window Functions
**File**: `sql/sltt_tiering.sql`  
**Skills**: Schema design, normalization, joins, calculated fields, SQL window functions.  

**Workflow**:
- Load incidents and population tables.  
- Compute `incidents per 100k` by county.  
- Use `NTILE(4)` to assign quartile-based risk tiers.  
- Output top results, easily exportable for BI dashboards.

---

### 4. Supply Chain Edge Construction
**File**: `sql/supply_chain_edges.sql`  
**Skills**: Relational joins, aggregation, preparing edge lists for network visualization.  

**Workflow**:
- Load `components.csv` (component + origin) and `integrations.csv` (component + integrator + units).  
- Aggregate flows from **origin → component** and **component → integrator**.  
- Output edge lists ready for visualization in Plotly or Power BI Sankey diagrams.

---

## 🔹 Excel Projects

### 5. SLTT Tiering Workbook
**File**: `excel/sltt_risk_tiering.xlsx`  
**Skills**: Data cleaning with helper columns, lookups, quartile binning, PivotTables.  

**Workflow**:
- Join incidents and population sheets with `XLOOKUP`.  
- Compute `rate per 100k` with formulas.  
- Apply `PERCENTILE.INC` thresholds to assign tiers.  
- Summarize results with PivotTables and conditional formatting.

---

### 6. Generator Power and Fuel Model
**File**: `excel/generator_model.xlsx`  
**Skills**: Engineering calculations, scenario analysis, sensitivity charts.  

**Workflow**:
- Inputs: generator rating, load factor, hours/day, fuel consumption, diesel properties.  
- Outputs: daily energy produced, fuel used, efficiency.  
- Scenario table with varying load factors.  
- Line charts showing efficiency and fuel consumption under different loads.

---




