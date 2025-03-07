# Colabfold workflow for MSA generation using MMseqs2

## Summary

MSA generation workflow using process described at https://github.com/sokrypton/ColabFold/blob/main/colabfold_search.sh.

## Workflow

```mermaid

flowchart TD
    A[FASTA file] -->B(Clean FASTA)
    B --> C(MMseqs2 UniRef30 Search)
    C --> C1((.a3m file))
    C --> C2((.m8 file)) 
    B --> D(MMseqs2 EnvDB Search)
    D --> D1((.a3m file))
    C --> E{Is complex?}
    E --> F(Paired MMseqs2 UniRef30 Search)
    F --> G((.a3m file))
    
```
