echo Uploading all files to github.com/joshbav/dcos-demo1
echo
# ALl files to automatically be added
git add .
git config user.name “joshbav” 
git commit -m "scripted commit $(date +%m-%d-%y)"
git push -u origin master

