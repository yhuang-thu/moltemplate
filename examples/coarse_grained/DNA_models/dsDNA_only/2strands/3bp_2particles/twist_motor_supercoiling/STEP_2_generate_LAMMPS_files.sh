# Use these commands to generate the LAMMPS input script and data file


# Create LAMMPS input files this way:

cd moltemplate_files

  # Use the "genpoly_lt.py" to generate a moltemplate file (.LT file)
  # describing the polymer you want to simulate.  You must specify the
  # name of the moltemplate object which will be used as the monomer subunit
  # in the final polymer (eg. "DNAMonomer"), as well as any bonds (or angles
  # or dihedrals) linking one monomer to the next monomer, as well as the
  # helical twist angle (if applicable).  All of the details regarding
  # the behaviour of the polymer are contained in the "dnamonomer.lt" file
  # which defines the "DNAMonomer" object, as well as a link to the file
  # which defines "DNAForceField" (which DNAMonomer uses).  For details, see:
  # https://github.com/jewettaij/moltemplate/blob/master/doc/doc_genpoly_lt.md

  genpoly_lt.py -circular yes \
                -helix 102.7797 \
                -bond Backbone a a \
                -bond Backbone b b \
                -dihedral MajorGroove b b a a 0 1 1 2 \
                -dihedral Torsion a a b b 1 0 0 1 \
                -polymer-name 'DNAPolymer' \
                -inherits 'DNAForceField'  \
                -monomer-name 'DNAMonomer' \
                -header 'import "dna_monomer.lt"' \
                -padding 20,20,20 \
                < init_crds_polymer_backbone.raw > dna_polymer.lt



  # (Note: The "-helix" parameter represents the twist-per-monomer (Δφ) at the
  #        start of the simulation.  Example "genpoly_lt.py -helix 102.857 ...")


  # Add twist motors.
  # If I only wanted to add a single twist motor, it would be easy to manually
  # add some extra lines to the "dna_polymer.lt" file.  However here I wrote
  # this script to make it possible to put many, many twist motors along the
  # polymer.  To do that, I created a new script named "genpoly_modify_lt.py"
  # which generates many modifications to a polymer at user-defined locations.
  # It's overkill for what we need in this example since we only use 1 motor.

  # "genpoly_modify_lt.py" needs to know the length of the polymer we created.
  # Count the number of non-blank, non-comment lines in the coordinate file:

  N_MONOMERS=`awk '{if ((NF>0) && (substr($1,1,1)!="#")) {n++}} END{print n}' < init_crds_polymer_backbone.raw`
  
  echo '' >> dna_polymer.lt
  echo 'import "dna_twist_motor.lt"' >> dna_polymer.lt
  echo '' >> dna_polymer.lt
  
  # Now run the script that makes (potentially)
  # many modifications to the polymer.
  # In our case it will modify the polymer to add a twist motor.
  # The position of that motor is in the file "mod_locations.txt"
  # (which currently only has one entry).  For more details, see:
  # https://github.com/jewettaij/moltemplate/blob/master/doc/doc_genpoly_modify_lt.md

  genpoly_modify_lt.py \
      -circular yes \
      -polymer-name DNAPolymer \
      -length $N_MONOMERS \
      -locations mod_locations.txt \
      -bond Motor   a a 1 2 \
      -bond Disable b b 1 2 \
      -dihedral MajorGrooveML b b a a 0 1 1 2 \
      -dihedral MajorGrooveMR a a b b 1 2 2 3 \
      -dihedral Disable       a a b b 2 1 1 2 \
      -dihedral Disable       b b a a 1 2 2 3 \
      -dihedral Disable       b a a b 1 1 2 2 \
      -set-atoms 6 "system.in.types" "type" b b a a b b 0 1 1 2 2 3 Bm2 Bm Am Am Bm Bm2 \
      -fix-nbody 4 "fix_twist_torque_5_kcal_per_radian.in" fxTw all twist torque b a a b 1 1 2 2 "5.0" \
      -fix-nbody 4 "fix_twist_constant_rate.in" fxTw all twist constrain b a a b 1 1 2 2 "5.0 100 8640" \
      >> dna_polymer.lt

  # NOTE: To force the motor to twist at a constant rate (instead of applying
  # a constant torque), use this instead.
  #
  # -fix-nbody 4 "fix_twist_rate_5.0_100_14400.in" fxTw all twist torque b a a b 1 1 2 2 "5.0 100 14400"
  # (WARNING:  Simulation can become numerically unstable if twisted too far.)

  # OPTIONAL Delete the bond interfering with the twist motor.
  echo '' >> dna_polymer.lt
  echo 'DNAPolymer {' >> dna_polymer.lt
  # Note: We already disabled this bond using "-bond Disable b b 1 2"
  #       (by setting its spring constant to 0).  However you actually have
  #       to delete that bond if you want it not to appear in visualization
  #       software tools like VMD (which was my goal).  To delete the bond,
  #       you have to know its $bond: name.  Bonds generated by genpoly_lt.py
  #       have names like "genp_bondi_j", where "j" indicates the monomer (from
  #       mod_locations.txt) and "i" represents the bond-per-monomer (2 here).
  awk -v N=$N_MONOMERS '{print "  delete genp_bond2_"($1+2)%N}' < mod_locations.txt >> dna_polymer.lt
  awk -v N=$N_MONOMERS '{print "  delete gpm_bond"($1+1)%N"_2"}' < mod_locations.txt >> dna_polymer.lt
  echo '}' >> dna_polymer.lt

  # Then run moltemplate on "system.lt".
  # (Note: "system.lt" contains a reference to the polymer file we created.)

  moltemplate.sh system.lt

  # This will generate various files with names ending in *.in* and *.data. 
  # These files are the input files directly read by LAMMPS.  Move them to 
  # the parent directory (or wherever you plan to run the simulation).
  mv -f system.in* fix_twist*.in system.data system.psf vmd_commands.tcl ../

  # Optional:
  # The "./output_ttree/" directory is full of temporary files generated by 
  # moltemplate. They can be useful for debugging, but are usually thrown away.
  rm -rf output_ttree/

  # Optional: Delete other temporary files:
  rm -f init_crds_polymer_backbone.raw
  rm -f dna_polymer.lt

cd ../

