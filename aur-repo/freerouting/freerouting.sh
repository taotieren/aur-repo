#!/usr/bin/bash

export PATH="/usr/lib/jvm/java-21-openjdk/bin/:$PATH"
java -jar /usr/lib/freerouting/freerouting-executable.jar "$@"

exit 0
