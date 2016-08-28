BUILD_DIR="${WORKSPACE}/ClassfitteriOS/build"
PAYLOAD_FILE=${BUILD_DIR}/payload.json
ARCHIVE_DIR="${BUILD_DIR}/archive"
EXPORT_DIR="${BUILD_DIR}/export"
EXPORT_CHECK_DIR="${BUILD_DIR}/export_check"
UPLOAD_DIR="${BUILD_DIR}/upload"
UPLOAD_CHECK_DIR="${BUILD_DIR}/upload_check"
VERSION_FILE="${BUILD_DIR}/version.txt"
FULL_VERSION_FILE="${BUILD_DIR}/fullversion.txt"
STATUS_FILE=${BUILD_DIR}/status.txt

rm -rf ${BUILD_DIR}
mkdir ${BUILD_DIR}
cat <<EOM > ${STATUS_FILE}
failure
EOM

#GETTING VERSION INFORMATION FROM payload
echo ${payload} > ${PAYLOAD_FILE}
VERSION_NUMBER=$(cftool getVersionFromPayload ${PAYLOAD_FILE})
echo "${VERSION_NUMBER}" > ${VERSION_FILE}

#VERSION
cftool setGitHubDeploymentStatusWithPayload ${PAYLOAD_FILE} 'pending' 'running' ${BUILD_URL}
cd ClassfitteriOS
agvtool new-marketing-version ${VERSION_NUMBER}
agvtool new-version -all ${BUILD_NUMBER}
cd ..

#ARCHIVE
mkdir ${ARCHIVE_DIR}
cd ClassfitteriOS
/usr/bin/xcodebuild -target ClassfitteriOS -configuration Release -scheme ClassfitteriOS  -archivePath ${ARCHIVE_DIR}/ClassfitteriOS archive

#EXPORT
mkdir ${EXPORT_DIR}
cat <<EOM > ${EXPORT_DIR}/exportOptions.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
        <key>teamID</key>
        <string>TQYB6VJLUN</string>
        <key>method</key>
        <string>app-store</string>
        <key>uploadSymbols</key>
        <true/>
</dict>
</plist>
EOM
xcrun xcodebuild -exportArchive -exportOptionsPlist ${EXPORT_DIR}/exportOptions.plist -archivePath ${ARCHIVE_DIR}/ClassfitteriOS.xcarchive -exportPath ${EXPORT_DIR}

#CHECK EXPORT
IPA_FILE=${EXPORT_DIR}/ClassfitteriOS.ipa
unzip -q  ${IPA_FILE} -d ${EXPORT_CHECK_DIR}
xcrun codesign -dv ${EXPORT_CHECK_DIR}/Payload/Classfitter.app

#CREATE ITSMP
set -ex
IPA_FILENAME=$(basename $IPA_FILE)
MD5=$(md5 -q $IPA_FILE)
BYTESIZE=$(stat -f "%z" $IPA_FILE)

mkdir ${UPLOAD_DIR}
ITSMP_FILE=${UPLOAD_DIR}/mybundle.itmsp
mkdir ${ITSMP_FILE}

cat <<EOM > ${ITSMP_FILE}/metadata.xml
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://apple.com/itunes/importer" version="software5.1">
	<provider>$PROVIDER</provider>
	<team_id>$TEAMID</team_id>
	<software>
		<vendor_id>$VENDORID</vendor_id>
		<software_assets>
			<asset type="bundle">
				<data_file>
					<size>$BYTESIZE</size>
					<file_name>$IPA_FILENAME</file_name>
					<checksum type="md5">$MD5</checksum>
				</data_file>
			</asset>
		</software_assets>
	</software>
</package>
EOM
cp ${IPA_FILE} ${ITSMP_FILE}

#CHECK UPLOAD
mkdir ${UPLOAD_CHECK_DIR}
/Applications/Xcode-beta.app/Contents/Applications/Application\ Loader.app/Contents/itms/bin/iTMSTransporter -m lookupMetadata -u ${ITUNES_USERNAME} -p ${ITUNES_PASSWORD} -vendor_id ${VENDORID} -destination ${UPLOAD_CHECK_DIR}
/Applications/Xcode-beta.app/Contents/Applications/Application\ Loader.app/Contents/itms/bin/iTMSTransporter -m verify -f ${ITSMP_FILE} -u ${ITUNES_USERNAME} -p ${ITUNES_PASSWORD} -v detailed

#UPLOAD
echo "Setting status to pending with payload:"
/Applications/Xcode-beta.app/Contents/Applications/Application\ Loader.app/Contents/itms/bin/iTMSTransporter -m upload -f ${ITSMP_FILE} -u ${ITUNES_USERNAME} -p ${ITUNES_PASSWORD} 
#--upload

#CREATE GITHUB RELEASE AND TAG  
data="{""tag_name"":""v"${VERSION_NUMBER}"+"${BUILD_NUMBER}""",""name"":""v"${VERSION_NUMBER}"+"${BUILD_NUMBER}"""}"
curl -d data -u $GITHUB_TOKEN:x-oauth-basic https://api.github.com/repos/classfitter/classfitter/releases

rm -rf ${STATUS_FILE}
cat <<EOM > ${BUILD_DIR}/status.txt
success
EOM

echo "v${VERSION_NUMBER}+${BUILD_NUMBER}" > ${FULL_VERSION_FILE}