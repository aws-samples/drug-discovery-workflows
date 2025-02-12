from setuptools import setup, find_packages

setup(
    name='Humatch',
    version='1.0.1',
    description='Fast, gene-specific joint humanisation of antibody heavy and light chains.',
    license='BSD 3-clause license',
    maintainer='Lewis Chinery',
    long_description_content_type='text/markdown',
    maintainer_email='lewis.chinery@dtc.ox.ac.uk',
    include_package_data=True,
    package_data={'': ['trained_models/*', 'germline_likeness_lookup_arrays/*', 'configs/*']},
    packages=find_packages(include=('Humatch', 'Humatch.*')),
    entry_points={'console_scripts': [
        'Humatch-align=Humatch.align:command_line_interface',
        'Humatch-classify=Humatch.classify:command_line_interface',
        'Humatch-humanise=Humatch.humanise:command_line_interface',
        ]},
    install_requires=[
        'numpy==2.0.2',
        # 'numpy>=1.26.4',
        'pandas==2.2.3',
        # 'pandas>=2.2.3',
        'ipykernel==6.29.5',
        # 'ipykernel>=6.29.5',
        'tensorflow==2.18.0',
        # 'tensorflow>=2.17.0',
        'scikit-learn==1.6.1',
        # 'scikit-learn>=1.5.2',
        'seaborn==0.13.2',
        # 'seaborn',
        'matplotlib==3.9.4',
        # 'matplotlib',
        'pyyaml==6.0.2',
        # 'pyyaml>=6.0.2',
        'biopython==1.85',
        # 'biopython>=1.84',  # for anarci numbering
        'hmmer==3.4.0.0',   # for anarci numbering
    ],
)
