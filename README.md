# Simulateur IADE

A Ruby on Rails application for simulating and explaining the remuneration of French public-hospital nurses, with a particular focus on **IADE** (Infirmiers Anesthésistes Diplômés d'État).

The project turns complex payroll and career rules into dedicated, testable domain services: salary index calculations, contributions, bonuses, overtime, NBI/SFT, absences, withholding tax and career progression.

## Highlights

- Monthly payslip simulation for IADE / IDE profiles
- Traitement indiciaire brut (TIB) from grade and echelon
- Part-time work quota handling
- NBI and supplément familial de traitement (SFT)
- IADE/IDE-specific bonuses and allowances
- Overtime and night-hours calculations
- Payroll contributions and CSG/CRDS
- French withholding tax (PAS)
- Career progression and next-echelon projection
- Absence-related payroll adjustments
- Payslip comparison services

## Domain-driven calculation layer

Most payroll logic lives outside controllers in dedicated services under `app/services/iade/`.

Key components include:

- `PayslipCalculator` — orchestrates the complete payslip calculation
- `TibCalculator` — computes index-based base salary
- `CotisationsCalculator` — payroll and pension contributions
- `CarriereCalculator` / `CarriereProjectionCalculator` — career progression
- `HeuresSupM2Calculator` — overtime and night-hour rules
- `NbiCalculator` — nouvelle bonification indiciaire
- `AbsencesCalculator` — absence-related adjustments
- `PayslipComparison` — comparison between simulation scenarios

This separation keeps complex business rules independently testable and makes future regulatory changes easier to isolate.

## Quality & security

The repository uses GitHub Actions on every push and pull request to `master`.

The CI pipeline checks:

- Rails automated tests
- RuboCop static code quality
- Brakeman Rails security analysis
- Bundler Audit dependency vulnerability scanning

The project includes dedicated business tests for salary indexes, contributions, career progression, payslip generation, part-time scenarios, NBI/SFT, overtime and tax-exemption rules.

## Tech stack

- Ruby 3.3.5
- Ruby on Rails 8.1
- PostgreSQL
- Bootstrap 5
- Hotwire / Turbo / Stimulus
- Devise
- Minitest
- GitHub Actions
- RuboCop
- Brakeman
- Bundler Audit

## Local setup

### Requirements

- Ruby 3.3.5
- PostgreSQL
- Bundler

### Installation

```bash
git clone https://github.com/TonyLawrence85/simulateur_iade.git
cd simulateur_iade
bundle install
bin/rails db:prepare
bin/rails server
```

Then open `http://localhost:3000`.

## Tests and quality checks

Run the test suite:

```bash
bin/rails test
```

Run the same quality/security checks used by CI:

```bash
bundle exec rubocop
bundle exec brakeman --no-pager
bundle exec bundler-audit check --update
```

## Project context

French public-hospital remuneration combines grade/echelon indexation with profession-specific bonuses, family supplements, working-time rules, pension contributions, overtime regimes and taxation. The purpose of this project is to model those rules in an understandable application while keeping the calculation engine structured and testable.

> **Disclaimer:** this application is an educational simulation tool. Results should not be treated as an official payroll statement or administrative calculation.

## Author

**Tony Lawrence**

Built as a full-stack Ruby on Rails project with a strong focus on domain modelling, automated testing and CI/security practices.
