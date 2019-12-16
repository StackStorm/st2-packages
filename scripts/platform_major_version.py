#!/usr/bin/env python
import platform

version = platform.linux_distribution(full_distribution_name=1)[1]
print(str.split(version, '.')[0])
