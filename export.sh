echo "Cleaning Old Files"
rm ./Export/Linux/*
rm ./Export/Windows/*
rm ./Export/Android/*
rm ./Export/Compressed/*

version=$(grep "config/version=" project.godot | cut -d\= -d\" -f2)

echo "Compiling Godot Project"
echo "Aether for Windows"
../Godot_Server --export "Linux/X11" ./Export/Linux/Aether_Linux_$version.x86_64
echo "Aether for Linux"
../Godot_Server --export "Windows Desktop" ./Export/Windows/Aether_Windows_$version.exe
echo "Aether for Android"
../Godot_Server --export "Android" ./Export/Android/Aether_Android_$version.apk

echo
echo
echo "Compressing Executables"
echo "Please Wait, this will take some time"
cd "./Export/Compressed"
7z a -t7z -mx=9 -mfb=273 -ms -md=31 -myx=9 -mtm=- -mmt -mmtf -md=1536m -mmf=bt3 -mmc=10000 -mpb=0 -mlc=0 Aether_Windows_$version "../Windows/Aether_Windows_$version.exe" > /dev/null & WINDOWS=$!
7z a -t7z -mx=9 -mfb=273 -ms -md=31 -myx=9 -mtm=- -mmt -mmtf -md=1536m -mmf=bt3 -mmc=10000 -mpb=0 -mlc=0 Aether_Linux_$version   "../Linux/Aether_Linux_$version.x86_64"  > /dev/null & LINUX=$!
7z a -t7z -mx=9 -mfb=273 -ms -md=31 -myx=9 -mtm=- -mmt -mmtf -md=1536m -mmf=bt3 -mmc=10000 -mpb=0 -mlc=0 Aether_Android_$version   "../Android/Aether_Android_$version.apk"  > /dev/null & ANDROID=$!

wait $WINDOWS
wait $LINUX
wait $ANDROID

echo
pwd
ls

echo
echo
echo "Done"
