import argparse
import os
import numpy as np
import torch

# ANTIPASTI
from antipasti.preprocessing.preprocessing import Preprocessing
from antipasti.utils.torch_utils import load_checkpoint

if __name__ == "__main__":
    # Argument parser
    parser = argparse.ArgumentParser(
        description="Predict binding affinity using ANTIPASTI."
    )
    parser.add_argument(
        "--test_data_path",
        type=str,
        required=True,
        help="Path to the test data directory.",
    )
    parser.add_argument(
        "--structures_path",
        type=str,
        required=True,
        help="Path to the structures directory.",
    )
    parser.add_argument(
        "--test_pdb",
        type=str,
        nargs="+",  # Accept multiple PDB IDs as a list
        required=True,
        help="List of PDB IDs of the antibodies to predict binding affinity.",
    )
    parser.add_argument(
        "--output_csv",
        type=str,
        default="predicted_binding_affinity.csv",
        help="Output CSV file for predicted binding affinity.",
    )
    parser.add_argument(
        "--renew_maps",
        action="store_true",
        help="Recompute all the normal mode correlation maps.",
    )
    parser.add_argument(
        "--renew_residues",
        action="store_true",
        help="Retrieve again all the chain lengths.",
    )
    parser.add_argument(
        "--n_filters", type=int, default=4, help="Number of filters for the model."
    )
    parser.add_argument(
        "--filter_size", type=int, default=4, help="Filter size for the model."
    )
    parser.add_argument(
        "--pooling_size", type=int, default=1, help="Pooling size for the model."
    )
    parser.add_argument(
        "--n_max_epochs",
        type=int,
        default=1044,
        help="Number of maximum epochs for the model.",
    )
    parser.add_argument(
        "--modes",
        type=str,
        default="all",
        help="Modes for the model. 'all' or integer values.",
    )
    parser.add_argument(
        "--stage", type=str, default="predicting", help="Stage of the model."
    )
    args = parser.parse_args()

    # Assign arguments to variables
    test_data_path = args.test_data_path
    structures_path = args.structures_path
    test_pdb_list = args.test_pdb  # This is now a list of PDB IDs
    output_csv = args.output_csv
    renew_maps = args.renew_maps
    renew_residues = args.renew_residues
    n_filters = args.n_filters
    filter_size = args.filter_size
    pooling_size = args.pooling_size
    n_max_epochs = args.n_max_epochs
    modes = args.modes
    stage = args.stage

    pathological = [
        "5omm",
        "5i5k",
        "1uwx",
        "1mj7",
        "1qfw",
        "1qyg",
        "4ffz",
        "3ifl",
        "3lrh",
        "3pp4",
        "3ru8",
        "3t0w",
        "3t0x",
        "4fqr",
        "4gxu",
        "4jfx",
        "4k3h",
        "4jfz",
        "4jg0",
        "4jg1",
        "4jn2",
        "4o4y",
        "4qxt",
        "4r3s",
        "4w6y",
        "4w6y",
        "5ies",
        "5ivn",
        "5j57",
        "5kvd",
        "5kzp",
        "5mes",
        "5nmv",
        "5sy8",
        "5t29",
        "5t5b",
        "5vag",
        "3etb",
        "3gkz",
        "3uze",
        "3uzq",
        "4f9l",
        "4gqp",
        "4r2g",
        "5c6t",
        "3fku",
        "1oau",
        "1oay",
    ]
    scfv = [
        "4gqp",
        "3etb",
        "3gkz",
        "3uze",
        "3uzq",
        "3gm0",
        "4f9l",
        "6ejg",
        "6ejm",
        "1h8s",
        "5dfw",
        "6cbp",
        "4f9p",
        "5kov",
        "1dzb",
        "5j74",
        "5aaw",
        "3uzv",
        "5aam",
        "3ux9",
        "5a2j",
        "5a2k",
        "5a2i",
        "3fku",
        "5yy4",
        "3uyp",
        "5jyl",
        "1y0l",
        "1p4b",
        "3kdm",
        "4lar",
        "4ffy",
        "2ybr",
        "1mfa",
        "5xj3",
        "5xj4",
        "4kv5",
        "5vyf",
    ]
    pathological += scfv

    dccm_map_path = "dccm_maps_full_ags_all/"
    test_dccm_map_path = "dccm_map/"
    test_residues_path = "list_of_residues/"
    test_structure_path = "structure/"

    # Open the output CSV file for writing
    output_file = os.path.join(os.getcwd(), output_csv)
    with open(output_file, "w") as f:
        f.write("PDB ID,Out Value,Predicted Binding Affinity\n")

        for test_pdb in test_pdb_list:
            # get base name (no extension)
            test_pdb_base = os.path.splitext(os.path.basename(test_pdb))[0]

            preprocessed_data = Preprocessing(
                dccm_map_path=dccm_map_path,
                modes=modes,
                pathological=pathological,
                renew_maps=renew_maps,
                renew_residues=renew_residues,
                stage=stage,
                test_data_path=test_data_path,
                test_dccm_map_path=test_dccm_map_path,
                test_residues_path=test_residues_path,
                test_structure_path=test_structure_path,
                test_pdb_id=test_pdb_base,
                structures_path=structures_path,
                # alphafold=True,
            )
            input_shape = preprocessed_data.test_x.shape[-1]

            # Validate the inputs
            path = (
                "../checkpoints/full_ags_all_modes/model_epochs_"
                + str(n_max_epochs)
                + "_modes_"
                + str(modes)
                + "_pool_"
                + str(pooling_size)
                + "_filters_"
                + str(n_filters)
                + "_size_"
                + str(filter_size)
                + ".pt"
            )

            # Validate the inputs
            if not os.path.exists(path):
                raise FileNotFoundError(f"Checkpoint file {path} does not exist. Ensure arguments: n_max_epochs, modes, pooling_size, n_filters, and filter_size are correct.")

            model, optimiser, _, train_losses, test_losses = load_checkpoint(path, input_shape)
            model.eval()

            # We convert to the torch format
            test_sample = torch.from_numpy(
                preprocessed_data.test_x.reshape(1, 1, input_shape, input_shape).astype(
                    np.float32
                )
            )

            out_val = model(test_sample)[0].detach().numpy()[0, 0]
            print(f"The output value for {test_pdb_base} is " + str(out_val))
            print(f"So the predicted binding affinity for {test_pdb_base} is " + str(10**out_val))

            # Write the result to the CSV file
            f.write(f"{test_pdb_base},{str(out_val)},{str(10**out_val)}\n")

    print(f"Predicted binding affinities saved to {output_file}")
