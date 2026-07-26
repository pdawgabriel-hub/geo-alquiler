<a id="top"></a>
# GeoAlquiler

[Español](./README.md) | **English**

### Real Estate Intelligence and Spatial Analysis for the Rental Market

![R](https://img.shields.io/badge/R-4.x-276DC3?logo=r&logoColor=white)
![Shiny](https://img.shields.io/badge/Shiny-App-blue?logo=rstudio&logoColor=white)
![golem](https://img.shields.io/badge/Framework-golem-6E4A7E)
![License](https://img.shields.io/badge/License-Portfolio%20%2F%20Restricted%20Use-red)
![Status](https://img.shields.io/badge/Status-In%20development-yellow)

---

## Table of Contents

- [Overview](#overview)
- [Key Features / Modules](#key-features)
  - [1. Spatial Exploration](#spatial-exploration)
  - [2. Analytics & Machine Learning](#analytics-ml)
  - [3. Investment Tools](#investment-tools)
- [Screenshots](#screenshots)
- [Project Structure (`{golem}`)](#project-structure)
- [Requirements & Installation](#requirements-installation)
- [Usage & Execution](#usage-execution)
- [Usage from the Terminal (without RStudio)](#terminal-usage)
- [Testing & Quality](#testing-quality)
- [Deployment](#deployment)
- [License](#license)
- [Author](#author)

---

<a id="overview"></a>
## Overview

**GeoAlquiler** is an analytical web application built in **R** with **Shiny**, designed to turn raw rental listing data into **actionable market intelligence**. The project combines geolocation, data science, and financial decision-making tools into a single interactive dashboard, allowing a user (investor, analyst, or individual) to answer questions such as:

- Where are the areas with the best price/m² ratio in a city?
- What would be a "fair" market price for a property with a given set of characteristics?
- Which listings in the dataset stand out as investment opportunities compared to the rest of the market?
- What would be the estimated return and cash flow if I buy a specific property to rent it out?

To achieve this, GeoAlquiler is built on three pillars:

1. **Spatial Exploration** — visualize and filter the property stock on an interactive map.
2. **Analytics & Machine Learning** — extract patterns, generate price predictions, and recommend similar properties.
3. **Investment Tools** — turn the data into concrete buy/rent decisions through calculators and comparisons.

The project is designed as a **technical portfolio piece**, demonstrating mastery of Shiny application architecture at the R-package level (the `{golem}` framework), modularization, testing best practices, and a product-oriented approach to a real use case (PropTech / Real Estate Analytics).

[⬆ Back to top](#top)

---

<a id="key-features"></a>
## Key Features / Modules

The application is organized into three functional blocks, directly reflected in the interface's navigation (`sidebarMenu`), plus an informational section:

<a id="spatial-exploration"></a>
### 1. Spatial Exploration

| Module | Description |
|---|---|
| **Main Dashboard** | KPI overview with average price, average surface area, price per m², and total available properties based on the active filters. |
| **Interactive Map** (`mod_mapa`) | Map built with `leaflet`/`leaflet.extras`, geolocating each property and featuring a **heatmap layer** that visually reveals price and supply concentration by area. |
| **Global Filters Panel** (`mod_filtros`) | Collapsible horizontal filter bar (city, property type, price range, surface area, number of rooms, etc.) that reactively feeds **every** module in the application. |
| **Data Explorer** (`mod_tabla`) | Interactive table (`DT`) of the filtered listings, with a visual favorites indicator and result export. |
| **Neighborhood Analysis** (`mod_barrios`) | Zonal analytics: price dispersion, average value per m², and supply volume broken down by district/neighborhood within each city. |
| **My Favorites** (`mod_favoritos`) | Management of a list of properties bookmarked by the user during the session, with its own KPIs (average price of favorites, total saved, etc.). |
| **Export Data** (`mod_exportar`) | CSV download of the filtered subset of listings. |

<a id="analytics-ml"></a>
### 2. Analytics & Machine Learning

| Module | Description |
|---|---|
| **Visual Analytics** (`mod_graficos`) | Interactive `plotly` visualizations: price vs. surface area relationship, price distribution, and graphical market comparisons. |
| **Advanced Statistics** (`mod_estadistica`) | Statistical summary of the filtered market: median, percentiles, boxplots, and other dispersion measures to understand the real price distribution (beyond the average). |
| **ML Prediction** (`mod_prediccion`) | Predictive price model (regression) trained on the dataset, estimating the expected rent for a property based on city, neighborhood, property type, surface area, and number of rooms entered by the user. |
| **KNN Recommender** (`mod_recomendador`) | Recommendation system based on the **K-Nearest Neighbors** algorithm: given a reference property, it suggests the most similar listings in the dataset based on their characteristics. |

<a id="investment-tools"></a>
### 3. Investment Tools

| Module | Description |
|---|---|
| **A/B Comparator** (`mod_comparador`) | Head-to-head comparison between two cities, neighborhoods, or property types, useful for deciding between two alternative markets or segments. |
| **Opportunity Detector** (`mod_oportunidades`) | Automatically identifies listings that deviate favorably from the market average (e.g., price below what's expected for their area/type), flagging them as potential investment opportunities. |
| **Profitability Calculator** (`mod_calculadora`) | Complete financial calculator: gross/net yield, mortgage amortization, and cash flow projection based on purchase price, estimated rent, and maintenance costs. |
| **Executive Report** (`mod_reporte`) | Generation and download of a report (based on the `reporte_plantilla.Rmd` template) with the market's key metrics and the filtered listings, ready to share or print. |

[⬆ Back to top](#top)

---

<a id="screenshots"></a>
## Screenshots

Below are the application's main screens, organized by the same three functional blocks as the navigation. Replace each placeholder with your own screenshot following the guide in the next section.

### Spatial Exploration

| Main Dashboard |
|---|
| ![Main Dashboard](man/figures/panel-principal.png) |

| Data Explorer | Neighborhood Analysis |
|---|---|
| ![Data Explorer](man/figures/explorador-datos.png) | ![Neighborhood Analysis](man/figures/analisis-barrios.png) |

### Analytics & Machine Learning

| Visual Analytics | ML Prediction |
|---|---|
| ![Visual Analytics](man/figures/analitica-visual.png) | ![ML Prediction](man/figures/prediccion-ml.png) |

| KNN Recommender | Advanced Statistics |
|---|---|
| ![KNN Recommender](man/figures/recomendador-knn.png) | ![Advanced Statistics](man/figures/estadistica-avanzada.png) |

### Investment Tools

| A/B Comparator | Opportunity Detector |
|---|---|
| ![A/B Comparator](man/figures/comparador-ab.png) | ![Opportunity Detector](man/figures/detector-oportunidades.png) |

| Profitability Calculator | Executive Report |
|---|---|
| ![Profitability Calculator](man/figures/calculadora-rentabilidad.png) | ![Executive Report](man/figures/informe-ejecutivo.png) |

---

<a id="project-structure"></a>
## Project Structure (`{golem}`)

GeoAlquiler **is not a simple Shiny app in a single `app.R` file**, but rather an **R package** built with the **[`{golem}`](https://thinkr-open.github.io/golem/)** framework. This approach brings the advantages of a proper package (documentation with `roxygen2`, formal dependency management via `DESCRIPTION`, testing with `testthat`, and a clear development → build → deployment lifecycle) to a Shiny application of real-world size and complexity.

```
geo-alquiler/
├── DESCRIPTION            # Package metadata and dependencies (Imports)
├── app.R                  # Standardized launcher (pkgload::load_all + run_app())
├── R/                     # Package source code (app namespace)
│   ├── run_app.R          # Entry point: shinyApp(ui = app_ui, server = app_server)
│   ├── app_ui.R            # Global UI: dashboardPage, sidebarMenu, and tabItems
│   ├── app_server.R        # Global server: orchestrates reactive logic and calls each module
│   ├── mod_mapa.R           # Module: interactive map + heatmap
│   ├── mod_filtros.R        # Module: reactive global filters
│   ├── mod_tabla.R          # Module: data explorer (DT)
│   ├── mod_barrios.R        # Module: neighborhood analytics
│   ├── mod_favoritos.R      # Module: favorites management
│   ├── mod_exportar.R       # Module: CSV export
│   ├── mod_graficos.R       # Module: visual analytics (plotly)
│   ├── mod_estadistica.R    # Module: advanced statistics
│   ├── mod_prediccion.R     # Module: price prediction (ML)
│   ├── mod_recomendador.R   # Module: KNN recommender
│   ├── mod_comparador.R     # Module: A/B comparator
│   ├── mod_oportunidades.R  # Module: opportunity detector
│   ├── mod_calculadora.R    # Module: profitability calculator
│   └── mod_reporte.R        # Module: downloadable executive report
├── inst/
│   └── app/
│       └── data/           # Data bundled with the app (e.g. alquileres.parquet)
├── man/
│   └── figures/            # Screenshots used in this README
├── data/
│   └── processed/          # Processed data in .rds / .parquet formats
├── scripts/
│   └── convertir_parquet.R # Utility to convert/prepare datasets to Parquet format
├── generar_datos.R                # Data generation/preparation script
├── generar_datos_simulados.R      # Simulated data generation script for demo/development
├── reporte_plantilla.Rmd          # R Markdown template used by the Executive Report module
├── tests/
│   ├── testthat.R                 # Standard testthat runner for the package
│   └── testthat/
│       ├── test_calculos.R        # Calculation logic tests (price/m², KPIs, etc.)
│       ├── test_mod_tabla.R       # Tests for the table module
│       └── test_tabla.R           # Additional table/data tests
├── renv.lock                      # renv lockfile (dependency reproducibility)
└── geo-alquiler.Rproj             # RStudio project
```

### Architecture Philosophy

- **UI/Server separation per module**: each feature (map, prediction, calculator, etc.) lives in its own `mod_*.R` file, following the [Shiny Modules](https://shiny.posit.co/r/articles/improve/modules/) pattern (`NS(id)`, a `*UI()` function, and a `*Server()` function). This avoids `inputId`/`outputId` collisions and lets `app_ui.R` and `app_server.R` act as **orchestrators** rather than containers of business logic.
- **`app_ui.R`** defines exclusively the visual structure: the `dashboardPage` (`{shinydashboard}`), the navigation menu with its four blocks (Exploration, Analytics, Investment, Information), and the `tabItems` linking each tab to its corresponding module's `UI`.
- **`app_server.R`** is responsible for instantiating each module's `server`, passing shared reactive state (e.g., data already filtered by `mod_filtros`), and coordinating communication between modules when needed (e.g., favorites available in the table).
- **`run_app.R`** exposes the exported `run_app()` function, which wraps the `shinyApp` with `golem::with_golem_options()`, allowing configuration options (`golem_opts`) to be passed without touching the rest of the code — the standard pattern for any `{golem}`-based app.
- **`app.R`** at the root is the "universal" launcher: it runs `pkgload::load_all()` to load the package in development mode and enables `golem.app.prod = TRUE`, making it compatible with both local `shiny::runApp()` and deployment servers (Shiny Server, Posit Connect, shinyapps.io, Docker containers, etc.) without needing to install the package first.
- **Data as a bundled resource**: the dataset lives in `inst/app/data/`, ensuring it travels with the package and is available both in development and once installed/deployed, following `{golem}`'s convention for application assets.
- **Reproducible dependency management**: the project uses `{renv}` (`renv.lock` + `.Rprofile`) to pin exact versions of every package, ensuring the development and deployment environments are identical.

[⬆ Back to top](#top)

---

<a id="requirements-installation"></a>
## Requirements & Installation

### Prerequisites

- **R** ≥ 4.1 (4.3 or higher recommended)
- **RStudio** (recommended, though not required, developed in Visual Studio Code)
- Operating system: Windows, macOS, or Linux
- Internet connection for the initial dependency installation via `{renv}`

### Main Dependencies (`Imports` in `DESCRIPTION`)

| Package | Use in the project |
|---|---|
| [`golem`](https://cran.r-project.org/package=golem) | Framework for structuring the app as an R package |
| [`shiny`](https://cran.r-project.org/package=shiny) | Reactive engine and web framework for the application |
| [`shinydashboard`](https://cran.r-project.org/package=shinydashboard) | Dashboard layout (sidebar, boxes, valueBoxes) |
| [`arrow`](https://cran.r-project.org/package=arrow) | Efficient reading/writing of data in Parquet format |
| [`leaflet`](https://cran.r-project.org/package=leaflet) / [`leaflet.extras`](https://cran.r-project.org/package=leaflet.extras) | Interactive map and heatmap layer |
| [`DT`](https://cran.r-project.org/package=DT) | Interactive data tables |
| [`plotly`](https://cran.r-project.org/package=plotly) | Interactive visual analytics charts |

On top of this, `{testthat}` is used as a development dependency for the test suite, and `{renv}` for version control of all dependencies. You'll also need `{roxygen2}` installed to generate the package's `NAMESPACE` file (see step 4 of the installation) — without it, the application **won't start correctly**, since `NAMESPACE` is what tells R which functions from `shiny`, `leaflet`, `DT`, etc. should be made available to the app's code.

### Step-by-Step Installation

1. **Clone the repository**

   ```bash
   git clone <repository-URL>
   cd geo-alquiler
   ```

2. **Open the project in RStudio**

   Open the `geo-alquiler.Rproj` file. This will automatically set the working directory and activate `{renv}` via the project's `.Rprofile` (`source("renv/activate.R")`).

3. **Restore the dependency environment with `{renv}`**

   When you open the project, `{renv}` will detect `renv.lock` and offer to restore the environment. If it doesn't happen automatically, run it manually from the R console:

   ```r
   install.packages("renv")   # if not already installed
   renv::restore()
   ```

   This will install the exact same versions of every package (including `golem`, `shiny`, `leaflet`, `plotly`, etc.) that were used during the project's development.

4. **Generate the package's `NAMESPACE` with `{roxygen2}`**

   This step is **mandatory** the first time you clone the project (the `NAMESPACE` file is not committed pre-generated in the repository — it's built from the `#' @import`/`#' @importFrom` comments in the `R/` folder):

   ```r
   install.packages("roxygen2")   # if not already installed
   roxygen2::roxygenise()
   ```

   If you skip this step, `pkgload::load_all()` won't know which functions from `shiny`, `shinydashboard`, `leaflet`, `leaflet.extras`, `DT`, and `plotly` it should make available to the module code, and the app will fail with *"could not find function..."*-type errors.

5. **Verify that the package loads correctly**

   ```r
   pkgload::load_all()
   ```

   If no error appears (yellow `Warning` messages are normal), the package is ready to run.

[⬆ Back to top](#top)

---

<a id="usage-execution"></a>
## Usage & Execution

Since it's a `{golem}` package, the application **doesn't launch like a conventional Shiny script**, but through the exported `run_app()` function.

### Option 1 — From the R console (development mode)

```r
# Load the package into memory without installing it
pkgload::load_all()

# Launch the application
run_app()
```

### Option 2 — Running `app.R` directly

The `app.R` file at the project's root already wraps both steps above and enables `{golem}`'s production options. You can launch it:

- From RStudio, with the **Run App** button when opening `app.R`.
- From the terminal:

  ```bash
  Rscript app.R
  ```

### Option 3 — As an installed package

```r
# Install the package locally
devtools::install()

# Load and run it like any other library
library(GeoAlquiler)
run_app()
```

By default, the application will open in the browser (or RStudio's viewer) at `http://127.0.0.1:<port>`, showing the **Main Dashboard** with global KPIs and the heatmap as the entry point.

[⬆ Back to top](#top)

---

<a id="terminal-usage"></a>
## Usage from the Terminal (without RStudio)

Everything above can be done entirely from a Bash terminal, without ever opening RStudio — useful for servers, containers, CI/CD, or simply if you prefer the command line. The key is to use `Rscript` (R's non-interactive interpreter) instead of pasting code into the RStudio console.

### 1. Clone the repository

```bash
git clone <repository-URL>
cd geo-alquiler
```

### 2. Install/restore dependencies with `{renv}`

```bash
Rscript -e 'install.packages("renv", repos = "https://cloud.r-project.org")'
Rscript -e 'renv::restore()'
```

`renv::restore()` reads the `.Rprofile` and `renv.lock` just as if you had opened the `.Rproj` in RStudio, so it installs the exact same package versions.

### 3. Generate the package's `NAMESPACE` with `{roxygen2}`

Mandatory step, just like in RStudio: the `NAMESPACE` is not pre-generated in the repository, and without it `pkgload::load_all()` won't be able to make the `shiny`, `leaflet`, `DT`, `plotly`, etc. functions available to the code.

```bash
Rscript -e 'install.packages("roxygen2", repos = "https://cloud.r-project.org")'
Rscript -e 'roxygen2::roxygenise()'
```

### 4. Verify that the package loads correctly

```bash
Rscript -e 'pkgload::load_all()'
```

### 5. Run the application

Any of these three options is equivalent to clicking "Run App" in RStudio:

```bash
# Option A: using the launcher at the project's root
Rscript app.R

# Option B: loading the package in development mode and calling run_app()
Rscript -e 'pkgload::load_all(); run_app()'

# Option C: if you've already installed it as a package (devtools::install())
Rscript -e 'library(GeoAlquiler); run_app()'
```

> By default, `run_app()` will try to open a browser automatically, which doesn't exist on a server with no graphical environment. If you're running this remotely (a VM, a container, etc.), add `options(shiny.launch.browser = FALSE)` before calling `run_app()`, and optionally fix a port and host:
>
> ```bash
> Rscript -e 'pkgload::load_all(); options(shiny.launch.browser = FALSE); shiny::runApp(shiny::shinyApp(ui = app_ui, server = app_server), host = "0.0.0.0", port = 3838)'
> ```
>
> This way the app listens on `http://<server-IP>:3838` and you can access it from any browser without depending on the graphical environment of the machine it's running on.

### 6. Run the tests

```bash
Rscript -e 'testthat::test_dir("tests/testthat")'
```

or, if you have `{devtools}` installed (it's a heavy dependency, not required for everyday use):

```bash
Rscript -e 'devtools::test()'
```

### 7. Full package check (`R CMD check`)

Without needing `{devtools}`, using R's own command-line tools directly (this is also the equivalent used in a CI pipeline):

```bash
R CMD build .
R CMD check --no-manual GeoAlquiler_*.tar.gz
```

### Summary — RStudio ↔ Terminal Equivalents

| Action | In RStudio | In Bash |
|---|---|---|
| Restore dependencies | Offered when opening the `.Rproj` | `Rscript -e 'renv::restore()'` |
| Generate `NAMESPACE` | `Ctrl/Cmd + Shift + D` (or when building) | `Rscript -e 'roxygen2::roxygenise()'` |
| Load the package | `Ctrl/Cmd + Shift + L` | `Rscript -e 'pkgload::load_all()'` |
| Launch the app | "Run App" button | `Rscript app.R` |
| Run tests | `Ctrl/Cmd + Shift + T` | `Rscript -e 'testthat::test_dir("tests/testthat")'` |
| Full package check | `Ctrl/Cmd + Shift + E` | `R CMD build . && R CMD check --no-manual *.tar.gz` |

[⬆ Back to top](#top)

---

<a id="testing-quality"></a>
## Testing & Quality

GeoAlquiler includes a suite of **unit tests** with **[`{testthat}`](https://testthat.r-lib.org/)**, following the standard structure of an R package (`tests/testthat/`). The current tests cover, among other things, the logic behind metric calculations (e.g., price per m²) and the safe behavior of KPIs when given empty datasets, as well as the table module.

### Run all tests

From the R console, at the project's root:

```r
testthat::test_dir("tests/testthat")
```

or, if you have `{devtools}` installed:

```r
devtools::test()
```

### Run a specific test file

```r
testthat::test_file("tests/testthat/test_calculos.R")
```

### Full package check (build check)

For a more thorough validation — similar to what you'd run before a release or before pushing the package to a repository — the following is recommended:

```r
devtools::check()
```

This command verifies, in addition to the tests, the consistency of the `DESCRIPTION`, the `roxygen2` documentation, and the package's overall structure.

> **Best practices followed in this project:** each new calculation feature (price prediction, profitability, opportunity detection) should ideally come with a corresponding test in `tests/testthat/`, following the `test_that("description of the behavior", { expect_*(...) })` pattern already present in `test_calculos.R`.

[⬆ Back to top](#top)

---

<a id="deployment"></a>
## Deployment

Being built as a `{golem}` package with a launcher (`app.R`) decoupled from the development environment, GeoAlquiler is ready to be deployed on several common Shiny ecosystem environments:

In progress.....

It is recommended to:

1. Make sure `renv.lock` is up to date (`renv::snapshot()`) before deploying, to guarantee exact version reproducibility on the target server.
2. Verify that the required data (`inst/app/data/alquileres.parquet`) is included in the deployment, since the app depends on it to function.
3. Check that `options("golem.app.prod" = TRUE)` is active in production (already configured in `app.R`), which disables certain development helpers and optimizes startup.

[⬆ Back to top](#top)

---

<a id="license"></a>
## License

This project is published as a **personal portfolio piece** and carries a restricted-use license. Specifically:

- ✅ You **may view, clone, and run** the code for **learning, technical evaluation, or portfolio review purposes** (for example, as part of a hiring process or to study the project's architecture).
- ✅ You **may modify and run copies of the code for personal, non-commercial use**, always crediting the original authorship.
- ❌ **Commercial use of the project is not permitted**, in whole or in part (including deploying it as a product or service, reselling it, or integrating it into third-party commercial solutions) without the author's express authorization.
- 👤 **The sole rights-holder entitled to commercially exploit the project is the original author**, [Gabriel](https://github.com/pdawgabriel-hub) (author and developer of GeoAlquiler).

The full legal text can be found in the [`LICENSE.en.md`](./LICENSE.en.md) file (Spanish version: [`LICENSE.md`](./LICENSE.md)).

[⬆ Back to top](#top)

---

<a id="author"></a>
## Author

Developed by **Gabriel Iborra Vicente** as a portfolio project, with the goal of demonstrating the development of professional-grade Shiny applications structured as an R package (`{golem}`), combining geospatial analytics, Machine Learning models, and real estate investment decision-making tools.

[⬆ Back to top](#top)