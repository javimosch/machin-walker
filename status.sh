#!/usr/bin/env bash
# Self-serve training status: one cheap ssh, no persistent monitor.
ssh rbm21 'cat ~/machin-walker/STATUS.json 2>/dev/null' | python3 -m json.tool 2>/dev/null || echo "no STATUS.json yet (training not started or between writes)"
