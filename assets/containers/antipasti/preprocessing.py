# -*- coding: utf-8 -*-

r"""This module contains the pre-processing class. 

:Authors:   Kevin Michalewicz <k.michalewicz22@imperial.ac.uk>

"""

import glob
import numpy as np
import pandas as pd
import subprocess
import os

from config import DATA_DIR, SCRIPTS_DIR, STRUCTURES_DIR
from utils.generic_utils import remove_abc

class Preprocessing(object):
    r"""Generating the residue normal mode correlation maps.
    
    Parameters
    ----------
    data_path: str
        Path to the data folder.
    scripts_path: str
        Path to the scripts folder.
    structures_path: str
        Path to the PDB files.
    df: str
        Name of the database containing the PDB entries.
    modes: int
        Number of considered normal modes.
    chain_lengths_path: str
        Path to the folder containing arrays with the chain lengths.
    dccm_map_path: str
        Path to the normal mode correlation maps.
    residues_path: str
        Path to the folder containing the list of residues per entry.
    file_type_input: str
        Filename extension of input structures.
    selection: str
        Considered portion of antibody chains.
    pathological: list 
        PDB identifiers of antibodies that need to be excluded.
    renew_maps: bool
        Compute all the normal mode correlation maps.
    renew_residues: bool
        Retrieve the lists of residues for each entry.
    cmaps: bool
        If ``True``, ANTIPASTI computes the contact maps of the complexes instead of the Normal Modes.
    cmaps_thr: float
        Thresholding distance for alpha (α) carbons to build the contact maps.
    ag_agnostic: bool
        If ``True``, Normal Mode correlation maps are computed in complete absence of the antigen.
    affinity_entries_only: bool
        This is ``False`` in general, but the ANTIPASTI pipeline could be used to other types of projects and thus consider data without affinity values.
    stage: str
        Choose between ``training`` and ``predicting``.
    test_data_path: str
        Path to the test data folder.
    test_dccm_map_path: str
        Path to the test normal mode correlation maps.
    test_residues_path: str
        Path to the folder containing the list of residues for a test sample.
    test_structures_path: str
        Path to the test PDB file.
    test_pdb_id: str
        Test PDB ID.
    alphafold: bool
        ``True`` the test structure was folded using ``AlphaFold``.
    h_offset: int
        Amount of absent residues between positions 1 and 25 in the heavy chain.
    l_offset: int
        Amount of absent residues between positions 1 and 23 in the light chain.
        
    """

    def __init__(
            self,
            data_path=DATA_DIR,
            scripts_path=SCRIPTS_DIR,
            structures_path=STRUCTURES_DIR,
            df='sabdab_summary_all.tsv',
            modes=30,
            chain_lengths_path='chain_lengths/',
            dccm_map_path='dccm_maps/',
            residues_path='lists_of_residues/',
            file_type_input='.pdb',
            selection='_fv',
            pathological=None,
            renew_maps=False,
            renew_residues=False,
            cmaps=False,
            cmaps_thr=8.0,
            ag_agnostic=False,
            affinity_entries_only=True,
            stage='training',
            test_data_path=None,
            test_dccm_map_path=None,
            test_residues_path=None,
            test_structure_path=None,
            test_pdb_id='1t66',
            alphafold=False,
            h_offset=0,
            l_offset=0,
            ag_residues=0,
    ):
        self.data_path = data_path
        self.scripts_path = scripts_path
        self.structures_path = structures_path
        self.chain_lengths_path = data_path + chain_lengths_path
        self.dccm_map_path = data_path + dccm_map_path
        self.residues_path = data_path + residues_path
        self.modes = modes
        self.file_type_input = file_type_input
        self.selection = selection
        self.pathological = pathological
        self.cmaps = cmaps
        self.cmaps_thr = cmaps_thr
        self.ag_agnostic = ag_agnostic
        self.affinity_entries_only = affinity_entries_only
        self.stage = 'training'
        self.file_residues_paths = sorted(glob.glob(os.path.join(self.residues_path, '*.npy')))
        self.alphafold = alphafold
        self.h_offset = h_offset
        self.l_offset = l_offset
        self.ag_residues = ag_residues

        self.df_path = data_path + df
        self.entries, self.affinity, self.df = self.clean_df()
        self.heavy, self.light, self.selected_entries = self.initialisation(renew_maps, renew_residues)
        self.max_res_list_h, self.max_res_list_l, self.min_res_list_h, self.min_res_list_l = self.get_max_min_chains()
        self.train_x, self.train_y, self.labels, self.raw_imgs = self.load_training_images()
        self.stage = stage

        if self.stage != 'training':
            self.test_data_path = test_data_path
            self.test_dccm_map_path = self.test_data_path + test_dccm_map_path
            self.test_residues_path = self.test_data_path + test_residues_path
            self.test_structure_path = self.test_data_path + test_structure_path
            self.test_pdb_id = test_pdb_id
            self.test_x = self.load_test_image()


    def clean_df(self):
        r"""Cleans the database containing the PDB entries.

        Returns
        -------
        df_pdbs: list
            PDB entries.
        df_kds: list 
            Binding affinities.
        df: pandas.DataFrame
            Cleaned database.

        """

        df = pd.read_csv(self.df_path, sep='\t', header=0)[['pdb', 'antigen_type', 'affinity']]
        df.drop_duplicates(keep='first', subset='pdb', inplace=True)
        df['pdb'] = df['pdb'].str.lower().str.replace('+', '') # lowercase and remove '+' signs of scientific notation
        df = df[(df.antigen_type.notna()) & (df.antigen_type != 'NA')][['pdb', 'affinity']]
        if self.affinity_entries_only:
            df = df[(df.affinity.notna()) & (df.affinity != 'None')]
        df = df[~df['pdb'].isin(self.pathological)] # Removing pathological cases 

        return list(df['pdb']), list(df['affinity']), df

    def generate_fv_pdb(self, path, keepABC=True, lresidues=False, hupsymchain=None, lupsymchain=None):
        r"""Generates a new PDB file containing the antigen residues and the antibody variable region.

        Parameters
        ----------
        path: str
            Path of a Chothia-numbered PDB file.
        keepABC: bool
            Keeps residues whose name ends with a letter from 'A' to 'Z'.
        lresidues: bool
            The names of each residue are stored in ``self.residues_path``.
        upsymchain: int
            Upper limit of heavy chain residues due to a change in the numbering convention. Only useful when using ``AlphaFold``.
        lupsymchain: int
            Upper limit of light chain residues due to a change in the numbering convention. Only useful when using ``AlphaFold``.

        """

        amino_acid_dictionary = {'CYS': 'C', 'ASP': 'D', 'SER': 'S', 'GLN': 'Q', 'LYS': 'K',
        'ILE': 'I', 'PRO': 'P', 'THR': 'T', 'PHE': 'F', 'ASN': 'N', 'GLY': 'G', 'HIS': 'H', 
        'LEU': 'L', 'ARG': 'R', 'TRP': 'W', 'ALA': 'A', 'VAL':'V', 'GLU': 'E', 'TYR': 'Y', 'MET': 'M'}


        if self.stage == 'training':
            rpath = self.residues_path
        else:
            rpath = self.test_residues_path
        list_residues = ['START-Ab']

        with open(path, 'r') as f: # needs to be Chothia-numbered
            content = f.readlines()
            header_lines_important = range(4)
            header_lines = [content[i][0]=='R' for i in range(len(content))].count(True)
            h_range = range(1, 114)
            l_range = range(1, 108)
            residue_type_range = slice(17, 20)
            start_chain = 21
            chain_range = slice(start_chain, start_chain+1)
            res_range = slice(23, 26)
            res_extra_letter = 26 #sometimes includes a letter 'A', 'B', 'C', ...
            h_chain_key = 'HCHAIN'
            l_chain_key = 'LCHAIN'
            antigen_chain_key = 'AGCHAIN'
            idx_list = list(header_lines_important)
            idx_list_l = []
            idx_list_antigen = []
            antigen_chains = []
            new_path = path[:-4] + self.selection + path[-4:]
            # Getting the names of the heavy and antigen chains
            line = content[header_lines_important[-1]]
            if line.find(h_chain_key) != -1:
                h_pos = line.find(h_chain_key) + len(h_chain_key) + 1
                h_chain = line[h_pos:h_pos+1]
                antigen_pos = line.find(antigen_chain_key) + len(antigen_chain_key) + 1
                antigen_chains.append(line[antigen_pos:antigen_pos+1])
                for i in range(3):
                    if line[antigen_pos+2*i+1] in [',', ';']:
                        antigen_chains.append(line[antigen_pos+2*i+2]) # If two (or more) interacting antigen chains present
            else:
                # useful when using AlphaFold
                h_chain = 'A' 
                l_chain = 'B'
                antigen_chains = ['C', 'D', 'E']
                idx_list = [0]
                h_range = range(1-self.h_offset, hupsymchain-self.h_offset)
                l_range = range(1-self.l_offset, lupsymchain-self.l_offset)
                h_pos = start_chain
                l_pos = start_chain

            if line.find(l_chain_key) != -1:
                l_pos = line.find(l_chain_key) + len(l_chain_key) + 1
                l_chain = line[l_pos:l_pos+1]
            elif self.alphafold is False: 
                l_chain = None
                
            # Checking if H and L chains have the same name
            if l_chain is not None and h_chain.upper() == l_chain.upper():
                pathologic = True
                h_chain = h_chain.upper()
                l_chain = h_chain.lower()
            elif antigen_chains is not None and self.affinity_entries_only is False and (h_chain.upper() in antigen_chains or (l_chain is not None and l_chain.upper() in antigen_chains)):
                pathologic = True
                h_chain = h_chain.lower()
                if l_chain is not None:
                    l_chain = l_chain.lower()
            else:
                pathologic = False

            # Checks for matching identifiers
            if pathologic:
                if 'X' not in antigen_chains:
                    new_hchain = 'X'
                else: 
                    new_hchain = 'W'
                if 'Y' not in antigen_chains:
                    new_lchain = 'Y'
                else: 
                    new_lchain = 'Z'
            else:
                new_hchain = h_chain
                new_lchain = l_chain   
                           
            # Obtaining lines for the heavy chain variable region first
            for i, line in enumerate(content[header_lines:]):
                if line[chain_range].find(h_chain) != -1 and int(line[res_range]) in h_range:
                    if (line[res_extra_letter] == ' ' or keepABC == True) and line.find('HETATM') == -1:
                        idx_list.append(i+header_lines)
                        if lresidues == True:
                            full_res = line[res_range] + line[res_extra_letter]
                            if pathologic:
                                full_res = new_hchain + full_res
                            else:
                                full_res = line[chain_range] + full_res
                            full_res = amino_acid_dictionary[line[residue_type_range]] + full_res
                            if full_res != list_residues[-1]:
                                list_residues.append(full_res)

            # This separation ensures that heavy chain residues are enlisted first
            if l_chain is not None:
                for i, line in enumerate(content[header_lines:]):
                    if line[chain_range].find(l_chain) != -1 and int(line[res_range]) in l_range:
                        if (line[res_extra_letter] == ' ' or keepABC == True) and line.find('HETATM') == -1:
                            idx_list_l.append(i+header_lines)
                            if lresidues == True:
                                full_res = line[res_range] + line[res_extra_letter]
                                if pathologic:
                                    full_res = new_lchain + full_res
                                else:
                                    full_res = line[chain_range] + full_res
                                full_res = amino_acid_dictionary[line[residue_type_range]] + full_res
                                if full_res != list_residues[-1]:
                                    list_residues.append(full_res)                   
        
            if lresidues == True:
                list_residues.append('END-Ab')

            # Obtaining antigen(s)
            for i, line in enumerate(content[header_lines:]):
                if any(line[chain_range] in agc for agc in antigen_chains) and h_chain not in antigen_chains and l_chain not in antigen_chains:
                    idx_list_antigen.append(i+header_lines)
                    if lresidues == True:
                        full_res = line[chain_range] + line[res_range] + line[res_extra_letter]
                        if line[residue_type_range] in amino_acid_dictionary:
                            full_res = amino_acid_dictionary[line[residue_type_range]] + full_res
                            if full_res != list_residues[-1]:
                                list_residues.append(full_res)    

        # List with name of every residue is saved if selected
            saving_path = rpath + path[-8:-4] + '.npy'
            #if not os.path.exists(saving_path):
            np.save(saving_path, list_residues)
            
        # Creating new file
        with open(new_path, 'w') as f_new:
            f_new.writelines([content[l] for l in idx_list[:header_lines_important[-1]]])
            if l_chain is not None and self.alphafold is False:
                f_new.writelines([content[l][:h_pos]+new_hchain+content[l][h_pos+1:l_pos]+new_lchain+content[l][l_pos+1:] for l in idx_list[header_lines_important[-1]:header_lines_important[-1]+1]])
            else:
                f_new.writelines([content[l][:h_pos]+new_hchain+content[l][h_pos+1:] for l in idx_list[header_lines_important[-1]:header_lines_important[-1]+1]])
            f_new.writelines([content[l][:start_chain-5]+' '+content[l][start_chain-4:start_chain]+new_hchain+content[l][start_chain+1:] for l in idx_list[header_lines_important[-1]+1:]])
            if l_chain is not None:
                f_new.writelines([content[l][:start_chain-5]+' '+content[l][start_chain-4:start_chain]+new_lchain+content[l][start_chain+1:] for l in idx_list_l])
            if not self.ag_agnostic:
                f_new.writelines([content[l] for l in idx_list_antigen])
            if not self.cmaps:
                f_new.writelines([content[l] for l in range(len(content)) if content[l][0:6] == 'HETATM' and content[l][chain_range] in [h_chain, l_chain] and l not in idx_list+idx_list_l+idx_list_antigen])
            
    def generate_maps(self):
        r"""Generates the Normal Mode correlation maps.

        """
        for i, entry in enumerate(self.entries):
            file_name = entry + self.selection
            path = self.structures_path + file_name + self.file_type_input
            new_path = self.dccm_map_path + entry
            self.generate_fv_pdb(self.structures_path+entry+self.file_type_input, lresidues=True) 
            if not self.cmaps: # and len(np.load(self.residues_path + path[-11:-7] + '.npy')) > 500:
                # Print the command before executing it
                print('Running R script to generate DCCM map...')
                print('Command: /usr/local/bin/RScript '+str(self.scripts_path)+'pdb_to_dccm.r '+str(path)+' '+str(new_path)+' '+str(self.modes))
                subprocess.call(['/usr/local/bin/RScript', str(self.scripts_path)+'pdb_to_dccm.r', str(path), str(new_path), str(self.modes)], shell=False)
            #elif not self.cmaps:
            #    print(path[-11:-7])
            #    subprocess.call(['/usr/local/bin/RScript', str(self.scripts_path)+'pdb_to_dccm_aa.r', str(path), str(new_path), str(self.modes)], stdout=open(os.devnull, 'wb'))
            else:
                subprocess.call(['python', str(self.scripts_path)+'generate_contact_maps.py', str(path), str(new_path), str(self.cmaps_thr)])
            if os.path.exists(path):
                os.remove(path)
            
            if i % 25 == 0: 
                print('Map ' + str(i+1) + ' out of ' + str(len(self.entries)) + ' processed.')

    def get_lists_of_lengths(self, selected_entries):
        r"""Retrieves lists with the lengths of the heavy and light chains.
        
        Parameters
        ----------
        selected_entries: list
            PDB valid entries.

        Returns
        -------
        heavy: list
            Lengths of the heavy chains. In the context of the prediction stage, this list has one element.
        light: list 
            Lengths of the light chains. In the context of the prediction stage, this list has one element.
        selected_entries: list
            PDB valid entries. In the context of the prediction stage, this list has one element.

        """
        heavy = []
        light = []

        if self.stage == 'training':
            rpath = self.residues_path
        else:
            rpath = self.test_residues_path

        for entry in selected_entries:
            list_of_residues = list(np.load(rpath+entry+'.npy'))[1:]
            chain_pos = 0
            if 'END-Ab' in list_of_residues:
                list_of_residues = list_of_residues[:list_of_residues.index('END-Ab')]
                chain_pos = 1
            else:
                list_of_residues = list_of_residues[:-1]

            h_chain = list_of_residues[0][chain_pos]
            l_chain = list_of_residues[-1][chain_pos]

            heavy.append(len([idx for idx in list_of_residues if idx[chain_pos] == h_chain]))
            if h_chain != l_chain:
                light.append(len([idx for idx in list_of_residues if idx[chain_pos] == l_chain]))
            else:
                light.append(0)

        return heavy, light, selected_entries

    def get_max_min_chains(self):
        r"""Returns the longest and shortest possible chains.

        """
        max_res_list_h = []
        max_res_list_l = []

        for f in self.file_residues_paths:
            shift = 0
            if 'END-Ab' in np.load(f):
                shift = 1
            idx = self.selected_entries.index(f[-8:-4])
            current_list_h = np.load(f)[1:self.heavy[idx]+1]
            current_list_l = np.load(f)[self.heavy[idx]+1:self.heavy[idx]+self.light[idx]+1]
            current_list_h = [x[1+shift:] for x in current_list_h]
            current_list_l = [x[1+shift:] for x in current_list_l]
            max_res_list_h += list(set(current_list_h).difference(max_res_list_h))
            max_res_list_l += list(set(current_list_l).difference(max_res_list_l))
            
        max_res_list_h = sorted(max_res_list_h, key=remove_abc)
        min_res_list_h = list(dict.fromkeys([x for x in max_res_list_h]))
        max_res_list_h = [x.strip() for x in max_res_list_h]

        max_res_list_l = sorted(max_res_list_l, key=remove_abc)
        min_res_list_l = list(dict.fromkeys([x for x in max_res_list_l]))
        max_res_list_l = [x.strip() for x in max_res_list_l]

        for f in self.file_residues_paths:
            shift = 0
            if 'END-Ab' in f:
                shift = 1
            idx = self.selected_entries.index(f[-8:-4])
            current_list_h = np.load(f)[1:self.heavy[idx]+1]
            current_list_l = np.load(f)[self.heavy[idx]+1:self.heavy[idx]+self.light[idx]+1]
            current_list_h = [x[1+shift:] for x in current_list_h]
            current_list_l = [x[1+shift:] for x in current_list_l]
            min_res_list_h = sorted(list(set(current_list_h).intersection(min_res_list_h)))
            min_res_list_l = sorted(list(set(current_list_l).intersection(min_res_list_l)))

        min_res_list_h = [x.strip() for x in min_res_list_h]
        min_res_list_l = [x.strip() for x in min_res_list_l]

        return max_res_list_h, max_res_list_l, min_res_list_h, min_res_list_l


    def initialisation(self, renew_maps, renew_residues):
        r"""Computes the normal mode correlation maps and retrieves lists with the lengths of the heavy and light chains.

        Parameters
        ----------
        renew_maps: bool
            Compute all the normal mode correlation maps.
        renew_residues: bool
            Retrieve the lists of residues for each entry.

        Returns
        -------
        heavy: list
            Lengths of the heavy chains.
        light: list 
            Lengths of the light chains.
        selected_entries: list
            PDB valid entries.

        """

        if renew_maps:
            self.generate_maps()

        dccm_paths = sorted(glob.glob(os.path.join(self.dccm_map_path, '*.npy')))
        selected_entries = [dccm_paths[i][-8:-4] for i in range(len(dccm_paths))]

        if renew_residues:
            heavy, light, selected_entries = self.get_lists_of_lengths(selected_entries)
            np.save(self.chain_lengths_path+'heavy_lengths.npy', heavy)
            np.save(self.chain_lengths_path+'light_lengths.npy', light)
            np.save(self.chain_lengths_path+'selected_entries.npy', selected_entries)
        else:
            heavy = np.load(self.chain_lengths_path+'heavy_lengths.npy').astype(int)
            light = np.load(self.chain_lengths_path+'light_lengths.npy').astype(int)

        assert list(np.load(self.chain_lengths_path+'selected_entries.npy')) == selected_entries

        for entry in selected_entries:
            residues = list(np.load(self.residues_path+entry+'.npy'))
            if 'END-Ab' in residues:
                assert len(residues[:residues.index('END-Ab')])-1 == heavy[selected_entries.index(entry)] + light[selected_entries.index(entry)]

        return heavy, light, selected_entries

    def generate_masked_image(self, img, idx, test_h=None, test_l=None):
        r"""Generates a masked normal mode correlation map

        Parameters
        ----------
        img: numpy.ndarray
            Original array containing no blank pixels.
        idx: int
            Input index.
        test_h: int
            Length of the heavy chain of an antibody in the test set.
        test_l: int
            Length of the light chain of an antibody in the test set.

        Returns
        -------
        masked: numpy.ndarray
            Masked normal mode correlation map.
        mask: numpy.ndarray
            Mask itself.
        
        """
        if self.stage == 'training':    
            f = self.file_residues_paths[idx]
        elif self.alphafold is False:
            f = sorted(glob.glob(os.path.join(self.test_residues_path, '*'+self.test_pdb_id+'.npy')))[0]
        else:
            f = sorted(glob.glob(os.path.join(self.test_residues_path, '*'+self.test_pdb_id[:-3]+'.npy')))[0] # removing '_af' suffix
        antigen_max_pixels = self.ag_residues
        f_res = np.load(f)

        # We force unique elements
        self.max_res_list_h = list(dict.fromkeys(self.max_res_list_h))
        self.max_res_list_l = list(dict.fromkeys(self.max_res_list_l))
        max_res_h = len(self.max_res_list_h)
        max_res_l = len(self.max_res_list_l)
        max_res = max_res_h + max_res_l 
        masked = np.zeros((max_res+antigen_max_pixels, max_res+antigen_max_pixels))
        mask = np.zeros((max_res+antigen_max_pixels, max_res+antigen_max_pixels))
        
        if self.stage != 'training':
            h = test_h
            l = test_l
        else:
            current_idx = self.selected_entries.index(f[-8:-4])
            h = self.heavy[current_idx]
            l = self.light[current_idx]

        current_list_h = f_res[1:h+1]
        shift = len(f_res[1][:f_res[1].find(' ')])
        current_list_h = [x[shift:].strip() for x in current_list_h] # First letter is the type of amino acid and second letter is the chain ID
        current_list_l = f_res[h+1:h+l+1]
        current_list_l = [x[shift:].strip() for x in current_list_l]    

        idx_list = [i for i in range(max_res_h) if self.max_res_list_h[i] in current_list_h]
        idx_list += [i+max_res_h for i in range(max_res_l) if self.max_res_list_l[i] in current_list_l]
        idx_list += [i+max_res_h+max_res_l for i in range(min(antigen_max_pixels, img.shape[-1]-(h+l)))]
        for k, i in enumerate(idx_list):
            for l, j in enumerate(idx_list):
                masked[i, j] = img[k, l]
                mask[i, j] = 1
            
        return masked, mask

    def load_training_images(self):
        r"""Returns the input/output pairs of the model and their corresponding labels.

        
        """      
        imgs = []
        raw_imgs = []
        kds = []
        labels = []
        file_paths = sorted(glob.glob(os.path.join(self.dccm_map_path, '*.npy')))

        for f in file_paths:
            pdb_id = f[-8:-4]
            if pdb_id in self.selected_entries and pdb_id not in self.pathological:
                raw_sample = np.load(f)
                idx = self.entries.index(pdb_id)
                idx_new = self.selected_entries.index(pdb_id)
                labels.append(pdb_id)
                raw_imgs.append(raw_sample)
                imgs.append(self.generate_masked_image(raw_sample, idx_new)[0])
                if self.affinity_entries_only:
                    kds.append(np.log10(np.float32(self.affinity[idx])))

        assert labels == [item for item in self.selected_entries if item not in self.pathological]

        #for pdb in self.selected_entries:
        #    if pdb not in self.pathological and self.affinity_entries_only:
        #        assert np.float16(10**kds[[item for item in self.selected_entries if item not in self.pathological].index(pdb)] == np.float16(self.df[self.df['pdb']==pdb]['affinity'])).all()

        return np.array(imgs), np.array(kds), labels, raw_imgs

    def load_test_image(self):
        r"""Returns a test normal mode correlation map which is masked according to the existing residues in the training set.

        """  
        pdb_id = self.test_pdb_id

        if self.alphafold is True:
            h, l, _ = self.get_lists_of_lengths(selected_entries=str(pdb_id[:-3]).split())
            h = h[0] 
            l = l[0] 
            hupsymchain = 1 + h 
            lupsymchain = 1 + l 
            lresidues = False
        else:
            hupsymchain = None
            lupsymchain = None
            lresidues = True

        # Generating the normal mode correlation map
        file_name = pdb_id + self.selection
        path = self.test_structure_path + file_name + self.file_type_input
        new_path = self.test_dccm_map_path + pdb_id
        
        self.generate_fv_pdb(self.test_structure_path+pdb_id+self.file_type_input, lresidues=lresidues, hupsymchain=hupsymchain, lupsymchain=lupsymchain) 
        
        # Print the command before executing it
        print('Running R script to generate DCCM map...')
        print('Command: /usr/local/bin/RScript '+str(self.scripts_path)+'pdb_to_dccm.r '+str(path)+' '+str(new_path)+' '+str(self.modes))
        # Execute the command
        subprocess.call('/usr/local/bin/RScript '+str(self.scripts_path)+'pdb_to_dccm.r '+str(path)+' '+str(new_path)+' '+str(self.modes), shell=True)
        if os.path.exists(path):
            os.remove(path)

        # Getting lengths, residues and masking
        file_path = sorted(glob.glob(os.path.join(self.test_dccm_map_path, '*'+pdb_id+'.npy')))
        for f in file_path:
            raw_sample = np.load(f)
            if self.alphafold is False:
                h, l, _ = self.get_lists_of_lengths(selected_entries=str(pdb_id).split())
                h = h[0]
                l = l[0]

        return self.generate_masked_image(raw_sample, 0, test_h=int(h), test_l=int(l))[0]