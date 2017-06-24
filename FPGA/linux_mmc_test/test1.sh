trap "exit" INT
LOOP=1
while :
do 
    sudo python mmc.py
    echo "Loop:$LOOP"
    LOOP=$((LOOP+1))
done

