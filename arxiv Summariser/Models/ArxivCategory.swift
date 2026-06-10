import Foundation

struct ArxivCategory: Identifiable, Hashable {
    let id: String
    let displayName: String
    /// Top-level arXiv field, e.g. "Computer Science", "Physics".
    let group: String
    /// Archive code, e.g. "cs", "astro-ph", "cond-mat", "quant-ph".
    let archive: String

    private static let byID: [String: ArxivCategory] =
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func displayName(for id: String) -> String {
        byID[id]?.displayName ?? id
    }

    /// An archive-level sub-header within a field. `name` is empty for fields
    /// that have no archive split (their categories are listed directly).
    struct Subgroup: Identifiable {
        let name: String
        let categories: [ArxivCategory]
        var id: String { name.isEmpty ? "_flat" : name }
    }

    /// A top-level field (e.g. "Physics", "Computer Science") for the picker.
    struct Group: Identifiable {
        let name: String
        let subgroups: [Subgroup]
        var id: String { name }
        /// True when categories should be listed directly under the field
        /// header (no archive sub-headers) — every field except Physics.
        var isFlat: Bool { subgroups.count == 1 && subgroups[0].name.isEmpty }
    }

    /// Hierarchical picker model: fields → archive subgroups → categories.
    /// Physics splits into named archive subgroups (Astrophysics, …); every
    /// other field is a single unnamed subgroup. Built by scanning `all` in its
    /// canonical order, so ordering needs no sorting.
    static let groups: [Group] = {
        var fieldOrder: [String] = []
        var byField: [String: [ArxivCategory]] = [:]
        for category in all {
            if byField[category.group] == nil { fieldOrder.append(category.group) }
            byField[category.group, default: []].append(category)
        }
        return fieldOrder.map { field in
            let items = byField[field]!
            guard field == "Physics" else {
                return Group(name: field, subgroups: [Subgroup(name: "", categories: items)])
            }
            var archiveOrder: [String] = []
            var byArchive: [String: [ArxivCategory]] = [:]
            for category in items {
                if byArchive[category.archive] == nil { archiveOrder.append(category.archive) }
                byArchive[category.archive, default: []].append(category)
            }
            let subgroups = archiveOrder.map { archive in
                Subgroup(name: physicsArchiveNames[archive] ?? archive, categories: byArchive[archive]!)
            }
            return Group(name: field, subgroups: subgroups)
        }
    }()

    private static let physicsArchiveNames: [String: String] = [
        "astro-ph": "Astrophysics",
        "cond-mat": "Condensed Matter",
        "gr-qc": "General Relativity & Quantum Cosmology",
        "hep-ex": "High Energy Physics – Experiment",
        "hep-lat": "High Energy Physics – Lattice",
        "hep-ph": "High Energy Physics – Phenomenology",
        "hep-th": "High Energy Physics – Theory",
        "math-ph": "Mathematical Physics",
        "nlin": "Nonlinear Sciences",
        "nucl-ex": "Nuclear Experiment",
        "nucl-th": "Nuclear Theory",
        "physics": "Physics (general)",
        "quant-ph": "Quantum Physics",
    ]

    /// A short, readable keyword label for an arXiv category code (falls back to
    /// the full category name, then the raw code).
    static func keyword(for code: String) -> String {
        keywordLabels[code] ?? displayName(for: code)
    }

    private static let keywordLabels: [String: String] = [
        "cs.AI": "AI",
        "cs.LG": "Machine Learning",
        "cs.CL": "NLP",
        "cs.CV": "Vision",
        "cs.RO": "Robotics",
        "cs.CR": "Security",
        "cs.SE": "Software Eng",
        "cs.HC": "HCI",
        "cs.MA": "Multi-Agent",
        "cs.CY": "Computers & Society",
        "cs.NE": "Neural Computing",
        "cs.IR": "Info Retrieval",
        "cs.DC": "Distributed",
        "cs.DS": "Algorithms",
        "cs.DB": "Databases",
        "cs.SD": "Sound",
        "cs.GT": "Game Theory",
        "cs.SY": "Systems & Control",
        "cs.NI": "Networking",
        "cs.PL": "Prog Languages",
        "cs.LO": "Logic",
        "cs.IT": "Information Theory",
        "cs.GR": "Graphics",
        "eess.SP": "Signal Processing",
        "eess.SY": "Systems & Control",
        "eess.IV": "Image & Video",
        "eess.AS": "Audio & Speech",
        "stat.ML": "Machine Learning",
        "stat.ME": "Methodology",
        "stat.AP": "Applied Stats",
        "stat.TH": "Stats Theory",
        "math.OC": "Optimization",
        "math.NA": "Numerical Analysis",
        "math.PR": "Probability",
        "math.ST": "Stats Theory",
        "math.CO": "Combinatorics",
        "q-bio.NC": "Neuroscience",
        "q-bio.QM": "Quant Methods",
        "q-fin.ST": "Stat Finance",
        "q-fin.PM": "Portfolio Mgmt",
        "astro-ph.GA": "Galaxies",
        "astro-ph.CO": "Cosmology",
        "cond-mat.mtrl-sci": "Materials",
        "cond-mat.dis-nn": "Disordered Systems",
        "physics.comp-ph": "Computational Physics",
        "physics.optics": "Optics",
        "econ.EM": "Econometrics",
    ]
}
