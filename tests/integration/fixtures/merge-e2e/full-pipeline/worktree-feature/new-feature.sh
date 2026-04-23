#!/bin/sh
# new-feature.sh — safe feature introduced by work/full-pipeline-row commit 1
# This file lives under bin/frw.d/scripts/ which is NOT a protected path, so
# the merge should accept it without human intervention.
printf 'new-feature: hello from full-pipeline fixture\n'
