import Foundation

// The complete arXiv category taxonomy, authored in arXiv's canonical order
// (verified against https://arxiv.org/category_taxonomy). Section ordering in
// the topic picker falls out of this array order, so keep entries grouped by
// field — and Physics grouped by archive — exactly as below.
//
// To refresh when arXiv changes its taxonomy (~yearly), re-fetch the page above
// and update this list.
extension ArxivCategory {
    static let all: [ArxivCategory] = [
        // MARK: Computer Science (cs)
        ArxivCategory(id: "cs.AI", displayName: "Artificial Intelligence", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.AR", displayName: "Hardware Architecture", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.CC", displayName: "Computational Complexity", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.CE", displayName: "Computational Engineering, Finance, and Science", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.CG", displayName: "Computational Geometry", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.CL", displayName: "Computation and Language", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.CR", displayName: "Cryptography and Security", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.CV", displayName: "Computer Vision and Pattern Recognition", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.CY", displayName: "Computers and Society", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.DB", displayName: "Databases", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.DC", displayName: "Distributed, Parallel, and Cluster Computing", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.DL", displayName: "Digital Libraries", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.DM", displayName: "Discrete Mathematics", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.DS", displayName: "Data Structures and Algorithms", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.ET", displayName: "Emerging Technologies", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.FL", displayName: "Formal Languages and Automata Theory", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.GL", displayName: "General Literature", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.GR", displayName: "Graphics", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.GT", displayName: "Computer Science and Game Theory", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.HC", displayName: "Human-Computer Interaction", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.IR", displayName: "Information Retrieval", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.IT", displayName: "Information Theory", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.LG", displayName: "Machine Learning", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.LO", displayName: "Logic in Computer Science", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.MA", displayName: "Multiagent Systems", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.MM", displayName: "Multimedia", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.MS", displayName: "Mathematical Software", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.NA", displayName: "Numerical Analysis", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.NE", displayName: "Neural and Evolutionary Computing", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.NI", displayName: "Networking and Internet Architecture", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.OH", displayName: "Other Computer Science", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.OS", displayName: "Operating Systems", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.PF", displayName: "Performance", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.PL", displayName: "Programming Languages", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.RO", displayName: "Robotics", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.SC", displayName: "Symbolic Computation", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.SD", displayName: "Sound", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.SE", displayName: "Software Engineering", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.SI", displayName: "Social and Information Networks", group: "Computer Science", archive: "cs"),
        ArxivCategory(id: "cs.SY", displayName: "Systems and Control", group: "Computer Science", archive: "cs"),

        // MARK: Economics (econ)
        ArxivCategory(id: "econ.EM", displayName: "Econometrics", group: "Economics", archive: "econ"),
        ArxivCategory(id: "econ.GN", displayName: "General Economics", group: "Economics", archive: "econ"),
        ArxivCategory(id: "econ.TH", displayName: "Theoretical Economics", group: "Economics", archive: "econ"),

        // MARK: Electrical Engineering and Systems Science (eess)
        ArxivCategory(id: "eess.AS", displayName: "Audio and Speech Processing", group: "Electrical Engineering and Systems Science", archive: "eess"),
        ArxivCategory(id: "eess.IV", displayName: "Image and Video Processing", group: "Electrical Engineering and Systems Science", archive: "eess"),
        ArxivCategory(id: "eess.SP", displayName: "Signal Processing", group: "Electrical Engineering and Systems Science", archive: "eess"),
        ArxivCategory(id: "eess.SY", displayName: "Systems and Control", group: "Electrical Engineering and Systems Science", archive: "eess"),

        // MARK: Mathematics (math)
        ArxivCategory(id: "math.AC", displayName: "Commutative Algebra", group: "Mathematics", archive: "math"),
        ArxivCategory(id: "math.AG", displayName: "Algebraic Geometry", group: "Mathematics", archive: "math"),
        ArxivCategory(id: "math.AP", displayName: "Analysis of PDEs", group: "Mathematics", archive: "math"),
        ArxivCategory(id: "math.AT", displayName: "Algebraic Topology", group: "Mathematics", archive: "math"),
        ArxivCategory(id: "math.CA", displayName: "Classical Analysis and ODEs", group: "Mathematics", archive: "math"),
        ArxivCategory(id: "math.CO", displayName: "Combinatorics", group: "Mathematics", archive: "math"),
        ArxivCategory(id: "math.CT", displayName: "Category Theory", group: "Mathematics", archive: "math"),
        ArxivCategory(id: "math.CV", displayName: "Complex Variables", group: "Mathematics", archive: "math"),
        ArxivCategory(id: "math.DG", displayName: "Differential Geometry", group: "Mathematics", archive: "math"),
        ArxivCategory(id: "math.DS", displayName: "Dynamical Systems", group: "Mathematics", archive: "math"),
        ArxivCategory(id: "math.FA", displayName: "Functional Analysis", group: "Mathematics", archive: "math"),
        ArxivCategory(id: "math.GM", displayName: "General Mathematics", group: "Mathematics", archive: "math"),
        ArxivCategory(id: "math.GN", displayName: "General Topology", group: "Mathematics", archive: "math"),
        ArxivCategory(id: "math.GR", displayName: "Group Theory", group: "Mathematics", archive: "math"),
        ArxivCategory(id: "math.GT", displayName: "Geometric Topology", group: "Mathematics", archive: "math"),
        ArxivCategory(id: "math.HO", displayName: "History and Overview", group: "Mathematics", archive: "math"),
        ArxivCategory(id: "math.IT", displayName: "Information Theory", group: "Mathematics", archive: "math"),
        ArxivCategory(id: "math.KT", displayName: "K-Theory and Homology", group: "Mathematics", archive: "math"),
        ArxivCategory(id: "math.LO", displayName: "Logic", group: "Mathematics", archive: "math"),
        ArxivCategory(id: "math.MG", displayName: "Metric Geometry", group: "Mathematics", archive: "math"),
        ArxivCategory(id: "math.MP", displayName: "Mathematical Physics", group: "Mathematics", archive: "math"),
        ArxivCategory(id: "math.NA", displayName: "Numerical Analysis", group: "Mathematics", archive: "math"),
        ArxivCategory(id: "math.NT", displayName: "Number Theory", group: "Mathematics", archive: "math"),
        ArxivCategory(id: "math.OA", displayName: "Operator Algebras", group: "Mathematics", archive: "math"),
        ArxivCategory(id: "math.OC", displayName: "Optimization and Control", group: "Mathematics", archive: "math"),
        ArxivCategory(id: "math.PR", displayName: "Probability", group: "Mathematics", archive: "math"),
        ArxivCategory(id: "math.QA", displayName: "Quantum Algebra", group: "Mathematics", archive: "math"),
        ArxivCategory(id: "math.RA", displayName: "Rings and Algebras", group: "Mathematics", archive: "math"),
        ArxivCategory(id: "math.RT", displayName: "Representation Theory", group: "Mathematics", archive: "math"),
        ArxivCategory(id: "math.SG", displayName: "Symplectic Geometry", group: "Mathematics", archive: "math"),
        ArxivCategory(id: "math.SP", displayName: "Spectral Theory", group: "Mathematics", archive: "math"),
        ArxivCategory(id: "math.ST", displayName: "Statistics Theory", group: "Mathematics", archive: "math"),

        // MARK: Physics — Astrophysics (astro-ph)
        ArxivCategory(id: "astro-ph.CO", displayName: "Cosmology and Nongalactic Astrophysics", group: "Physics", archive: "astro-ph"),
        ArxivCategory(id: "astro-ph.EP", displayName: "Earth and Planetary Astrophysics", group: "Physics", archive: "astro-ph"),
        ArxivCategory(id: "astro-ph.GA", displayName: "Astrophysics of Galaxies", group: "Physics", archive: "astro-ph"),
        ArxivCategory(id: "astro-ph.HE", displayName: "High Energy Astrophysical Phenomena", group: "Physics", archive: "astro-ph"),
        ArxivCategory(id: "astro-ph.IM", displayName: "Instrumentation and Methods for Astrophysics", group: "Physics", archive: "astro-ph"),
        ArxivCategory(id: "astro-ph.SR", displayName: "Solar and Stellar Astrophysics", group: "Physics", archive: "astro-ph"),

        // MARK: Physics — Condensed Matter (cond-mat)
        ArxivCategory(id: "cond-mat.dis-nn", displayName: "Disordered Systems and Neural Networks", group: "Physics", archive: "cond-mat"),
        ArxivCategory(id: "cond-mat.mes-hall", displayName: "Mesoscale and Nanoscale Physics", group: "Physics", archive: "cond-mat"),
        ArxivCategory(id: "cond-mat.mtrl-sci", displayName: "Materials Science", group: "Physics", archive: "cond-mat"),
        ArxivCategory(id: "cond-mat.other", displayName: "Other Condensed Matter", group: "Physics", archive: "cond-mat"),
        ArxivCategory(id: "cond-mat.quant-gas", displayName: "Quantum Gases", group: "Physics", archive: "cond-mat"),
        ArxivCategory(id: "cond-mat.soft", displayName: "Soft Condensed Matter", group: "Physics", archive: "cond-mat"),
        ArxivCategory(id: "cond-mat.stat-mech", displayName: "Statistical Mechanics", group: "Physics", archive: "cond-mat"),
        ArxivCategory(id: "cond-mat.str-el", displayName: "Strongly Correlated Electrons", group: "Physics", archive: "cond-mat"),
        ArxivCategory(id: "cond-mat.supr-con", displayName: "Superconductivity", group: "Physics", archive: "cond-mat"),

        // MARK: Physics — single-category archives
        ArxivCategory(id: "gr-qc", displayName: "General Relativity and Quantum Cosmology", group: "Physics", archive: "gr-qc"),
        ArxivCategory(id: "hep-ex", displayName: "High Energy Physics - Experiment", group: "Physics", archive: "hep-ex"),
        ArxivCategory(id: "hep-lat", displayName: "High Energy Physics - Lattice", group: "Physics", archive: "hep-lat"),
        ArxivCategory(id: "hep-ph", displayName: "High Energy Physics - Phenomenology", group: "Physics", archive: "hep-ph"),
        ArxivCategory(id: "hep-th", displayName: "High Energy Physics - Theory", group: "Physics", archive: "hep-th"),
        ArxivCategory(id: "math-ph", displayName: "Mathematical Physics", group: "Physics", archive: "math-ph"),

        // MARK: Physics — Nonlinear Sciences (nlin)
        ArxivCategory(id: "nlin.AO", displayName: "Adaptation and Self-Organizing Systems", group: "Physics", archive: "nlin"),
        ArxivCategory(id: "nlin.CD", displayName: "Chaotic Dynamics", group: "Physics", archive: "nlin"),
        ArxivCategory(id: "nlin.CG", displayName: "Cellular Automata and Lattice Gases", group: "Physics", archive: "nlin"),
        ArxivCategory(id: "nlin.PS", displayName: "Pattern Formation and Solitons", group: "Physics", archive: "nlin"),
        ArxivCategory(id: "nlin.SI", displayName: "Exactly Solvable and Integrable Systems", group: "Physics", archive: "nlin"),

        // MARK: Physics — Nuclear
        ArxivCategory(id: "nucl-ex", displayName: "Nuclear Experiment", group: "Physics", archive: "nucl-ex"),
        ArxivCategory(id: "nucl-th", displayName: "Nuclear Theory", group: "Physics", archive: "nucl-th"),

        // MARK: Physics — Physics (general)
        ArxivCategory(id: "physics.acc-ph", displayName: "Accelerator Physics", group: "Physics", archive: "physics"),
        ArxivCategory(id: "physics.ao-ph", displayName: "Atmospheric and Oceanic Physics", group: "Physics", archive: "physics"),
        ArxivCategory(id: "physics.app-ph", displayName: "Applied Physics", group: "Physics", archive: "physics"),
        ArxivCategory(id: "physics.atm-clus", displayName: "Atomic and Molecular Clusters", group: "Physics", archive: "physics"),
        ArxivCategory(id: "physics.atom-ph", displayName: "Atomic Physics", group: "Physics", archive: "physics"),
        ArxivCategory(id: "physics.bio-ph", displayName: "Biological Physics", group: "Physics", archive: "physics"),
        ArxivCategory(id: "physics.chem-ph", displayName: "Chemical Physics", group: "Physics", archive: "physics"),
        ArxivCategory(id: "physics.class-ph", displayName: "Classical Physics", group: "Physics", archive: "physics"),
        ArxivCategory(id: "physics.comp-ph", displayName: "Computational Physics", group: "Physics", archive: "physics"),
        ArxivCategory(id: "physics.data-an", displayName: "Data Analysis, Statistics and Probability", group: "Physics", archive: "physics"),
        ArxivCategory(id: "physics.ed-ph", displayName: "Physics Education", group: "Physics", archive: "physics"),
        ArxivCategory(id: "physics.flu-dyn", displayName: "Fluid Dynamics", group: "Physics", archive: "physics"),
        ArxivCategory(id: "physics.gen-ph", displayName: "General Physics", group: "Physics", archive: "physics"),
        ArxivCategory(id: "physics.geo-ph", displayName: "Geophysics", group: "Physics", archive: "physics"),
        ArxivCategory(id: "physics.hist-ph", displayName: "History and Philosophy of Physics", group: "Physics", archive: "physics"),
        ArxivCategory(id: "physics.ins-det", displayName: "Instrumentation and Detectors", group: "Physics", archive: "physics"),
        ArxivCategory(id: "physics.med-ph", displayName: "Medical Physics", group: "Physics", archive: "physics"),
        ArxivCategory(id: "physics.optics", displayName: "Optics", group: "Physics", archive: "physics"),
        ArxivCategory(id: "physics.plasm-ph", displayName: "Plasma Physics", group: "Physics", archive: "physics"),
        ArxivCategory(id: "physics.pop-ph", displayName: "Popular Physics", group: "Physics", archive: "physics"),
        ArxivCategory(id: "physics.soc-ph", displayName: "Physics and Society", group: "Physics", archive: "physics"),
        ArxivCategory(id: "physics.space-ph", displayName: "Space Physics", group: "Physics", archive: "physics"),

        // MARK: Physics — Quantum Physics (quant-ph)
        ArxivCategory(id: "quant-ph", displayName: "Quantum Physics", group: "Physics", archive: "quant-ph"),

        // MARK: Quantitative Biology (q-bio)
        ArxivCategory(id: "q-bio.BM", displayName: "Biomolecules", group: "Quantitative Biology", archive: "q-bio"),
        ArxivCategory(id: "q-bio.CB", displayName: "Cell Behavior", group: "Quantitative Biology", archive: "q-bio"),
        ArxivCategory(id: "q-bio.GN", displayName: "Genomics", group: "Quantitative Biology", archive: "q-bio"),
        ArxivCategory(id: "q-bio.MN", displayName: "Molecular Networks", group: "Quantitative Biology", archive: "q-bio"),
        ArxivCategory(id: "q-bio.NC", displayName: "Neurons and Cognition", group: "Quantitative Biology", archive: "q-bio"),
        ArxivCategory(id: "q-bio.OT", displayName: "Other Quantitative Biology", group: "Quantitative Biology", archive: "q-bio"),
        ArxivCategory(id: "q-bio.PE", displayName: "Populations and Evolution", group: "Quantitative Biology", archive: "q-bio"),
        ArxivCategory(id: "q-bio.QM", displayName: "Quantitative Methods", group: "Quantitative Biology", archive: "q-bio"),
        ArxivCategory(id: "q-bio.SC", displayName: "Subcellular Processes", group: "Quantitative Biology", archive: "q-bio"),
        ArxivCategory(id: "q-bio.TO", displayName: "Tissues and Organs", group: "Quantitative Biology", archive: "q-bio"),

        // MARK: Quantitative Finance (q-fin)
        ArxivCategory(id: "q-fin.CP", displayName: "Computational Finance", group: "Quantitative Finance", archive: "q-fin"),
        ArxivCategory(id: "q-fin.EC", displayName: "Economics", group: "Quantitative Finance", archive: "q-fin"),
        ArxivCategory(id: "q-fin.GN", displayName: "General Finance", group: "Quantitative Finance", archive: "q-fin"),
        ArxivCategory(id: "q-fin.MF", displayName: "Mathematical Finance", group: "Quantitative Finance", archive: "q-fin"),
        ArxivCategory(id: "q-fin.PM", displayName: "Portfolio Management", group: "Quantitative Finance", archive: "q-fin"),
        ArxivCategory(id: "q-fin.PR", displayName: "Pricing of Securities", group: "Quantitative Finance", archive: "q-fin"),
        ArxivCategory(id: "q-fin.RM", displayName: "Risk Management", group: "Quantitative Finance", archive: "q-fin"),
        ArxivCategory(id: "q-fin.ST", displayName: "Statistical Finance", group: "Quantitative Finance", archive: "q-fin"),
        ArxivCategory(id: "q-fin.TR", displayName: "Trading and Market Microstructure", group: "Quantitative Finance", archive: "q-fin"),

        // MARK: Statistics (stat)
        ArxivCategory(id: "stat.AP", displayName: "Applications", group: "Statistics", archive: "stat"),
        ArxivCategory(id: "stat.CO", displayName: "Computation", group: "Statistics", archive: "stat"),
        ArxivCategory(id: "stat.ME", displayName: "Methodology", group: "Statistics", archive: "stat"),
        ArxivCategory(id: "stat.ML", displayName: "Machine Learning", group: "Statistics", archive: "stat"),
        ArxivCategory(id: "stat.OT", displayName: "Other Statistics", group: "Statistics", archive: "stat"),
        ArxivCategory(id: "stat.TH", displayName: "Statistics Theory", group: "Statistics", archive: "stat"),
    ]
}
