from setuptools import setup, find_packages

setup(
    name="Surface analyses",
    version="0.1",
    description="Hydrophobicity analyses based on SASA",
    author="Franz Waibl",
    author_email="franz.waibl@uibk.ac.at",
    packages=["surface_analyses", "surface_analyses.anarci_wrapper"],
    include_package_data=True,
    zip_safe=False,
    install_requires=['numpy==2.0.2', 'scipy==1.13.1', 'pandas==2.2.3', 'scikit-image==0.24.0', 'gisttools @ git+https://github.com/liedllab/gisttools.git@3b7d362d020e3b8c620e407de21bf58c760b7692', 'plyfile==1.1', 'matplotlib==3.9.4', 'pdb2pqr==3.6.2', 'biopython==1.85', 'rdkit==2024.9.5'],
    setup_requires=['pytest_runner'],
    tests_require=['pytest'],
    py_modules=[
        "surface_analyses.commandline_hydrophobic",
        "surface_analyses.structure",
        "surface_analyses.propensities",
        "surface_analyses.hydrophobic_potential",
        "surface_analyses.pdb",
        "surface_analyses.commandline_electrostatic",
    ],
    entry_points={
        'console_scripts': [
            'pep_patch_hydrophobic=surface_analyses.commandline_hydrophobic:main',
            'pep_patch_electrostatic=surface_analyses.commandline_electrostatic:main',
        ],
    },
)
