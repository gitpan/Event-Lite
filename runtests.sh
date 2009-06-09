#!/bin/sh

cover --delete
PERL5OPT=-MDevel::Cover=+select_re,+select_re,+select_re, prove t/*
cover

