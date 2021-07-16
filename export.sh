echo "Compiling Godot Project"
echo "Aether for Windows"
../Godot_Server --export "Linux/X11" ./Export/Linux/Aether_Linux.x86_64
echo "Aether for Linux"
../Godot_Server --export "Windows Desktop" ./Export/Windows/Aether_Windows.exe

echo
echo
echo "Compressing Executables"
echo "Please Wait, this will take some time"
7z a -t7z -mx=9 -mfb=273 -ms -md=31 -myx=9 -mtm=- -mmt -mmtf -md=1536m -mmf=bt3 -mmc=10000 -mpb=0 -mlc=0 Aether_Windows "./Export/Windows/Aether_Windows.exe" > /dev/null & WINDOWS=$!
7z a -t7z -mx=9 -mfb=273 -ms -md=31 -myx=9 -mtm=- -mmt -mmtf -md=1536m -mmf=bt3 -mmc=10000 -mpb=0 -mlc=0 Aether_Linux   "./Export/Linux/Aether_Linux.x86_64"  > /dev/null & LINUX=$!

wait $WINDOWS
wait $LINUX

echo "Done"
