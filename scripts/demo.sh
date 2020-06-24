#!/bin/bash

#bash scripts/console-runner.sh ruby diclophis/draw_a_square.rb
#bash scripts/console-runner.sh ruby diclophis/explore-world.rb 16 64 tnt

######## glass sphere at 0,0
#cat openscad/sphere.scad \
#  | bash scripts/console-runner.sh ruby diclophis/scad.rb \
#  | bash scripts/console-runner.sh ruby diclophis/stl_stdin_blit_vox.rb \
#  128 80 80 0 air
#
#cat openscad/sphere.scad \
#  | bash scripts/console-runner.sh ruby diclophis/scad.rb \
#  | bash scripts/console-runner.sh ruby diclophis/stl_stdin_blit_vox.rb \
#  64 80 80 0 air

######### makes the giant mavencraft logo
#echo "★ hello bella and ivy ♥ ♥ ♥ ♥" \
#  | bash scripts/console-runner.sh ruby diclophis/text.rb \
#  | bash scripts/console-runner.sh ruby diclophis/stl_stdin_blit_vox.rb \
#  300 80 360 0 stone

##### dragon
#cat models/low_drogon-r1.stl \
#  | bash scripts/console-runner.sh ruby diclophis/stl_stdin_blit_vox.rb \
#  144 -190 160 285 stone
#
#### nyc
#cat models/nyc-no-floor.stl \
#  | bash scripts/console-runner.sh ruby diclophis/stl_stdin_blit_vox.rb \
#  1357 256 679 -256 quartz_block
#
###### serpinski pyramid
cat eisenscript/pyramid.es \
  | bash scripts/console-runner.sh ruby diclophis/structure_synth_inline.rb openscad/structure-synth.mlx \
  | bash scripts/console-runner.sh ruby diclophis/stl_stdin_blit_vox.rb \
  32 5 65 140 sandstone
#
####### base loft
#cat eisenscript/loft-like.es \
#  | bash scripts/console-runner.sh ruby diclophis/structure_synth_inline.rb openscad/structure-synth.mlx \
#  | bash scripts/console-runner.sh ruby diclophis/stl_stdin_blit_vox.rb \
#  100 -256 65 -256 stone
#
###### simple buildings
#cat eisenscript/block-of-buildings.es \
#  | bash scripts/console-runner.sh ruby diclophis/structure_synth_inline.rb openscad/structure-synth.mlx \
#  | bash scripts/console-runner.sh ruby diclophis/stl_stdin_blit_vox.rb \
#  90 -256 160 -256 stone
#
##### bridge
#cat eisenscript/simple-structures.es \
#  | bash scripts/console-runner.sh ruby diclophis/structure_synth_inline.rb openscad/structure-synth.mlx \
#  | bash scripts/console-runner.sh ruby diclophis/stl_stdin_blit_vox.rb \
#  200 -64 159 -64 stone
