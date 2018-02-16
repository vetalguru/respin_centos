#!/bin/bash

checkIfUserIsRoot()
{
    [ ! "$EUID" -ne 0 ]
}


