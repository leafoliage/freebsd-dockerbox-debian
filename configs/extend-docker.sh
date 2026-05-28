#!/bin/sh
growpart /dev/vdb 1
resize2fs /dev/vdb1
