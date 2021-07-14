#! /bin/bash

 # Script For Building Android arm64 Kernel
 #
 # Copyright (c) 2018-2020 Panchajanya1999 <rsk52959@gmail.com>
 #
 # Licensed under the Apache License, Version 2.0 (the "License");
 # you may not use this file except in compliance with the License.
 # You may obtain a copy of the License at
 #
 #      http://www.apache.org/licenses/LICENSE-2.0
 #
 # Unless required by applicable law or agreed to in writing, software
 # distributed under the License is distributed on an "AS IS" BASIS,
 # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 # See the License for the specific language governing permissions and
 # limitations under the License.
 #

#Kernel building script

# Function to show an informational message
msg() {
    echo -e "\e[1;32m$*\e[0m"
}

err() {
    echo -e "\e[1;41m$*\e[0m"
    exit 1
}

##------------------------------------------------------##
##----------Basic Informations, COMPULSORY--------------##

# The defult directory where the kernel should be placed
KERNEL_DIR=$PWD

# Devices variable
ZIPNAME="SiLonT-4nineteen"
MODEL="Redmi Note 5 Pro"
DEVICE="whyred"
DEFCONFIG=vendor/whyred_defconfig

# EnvSetup
KBUILD_BUILD_USER="reina"
KBUILD_BUILD_HOST=Laptop-Sangar
export CHATID="-1001403511595"
export KBUILD_BUILD_HOST KBUILD_BUILD_USER

export KBUILD_BUILD_VERSION=$DRONE_BUILD_NUMBER
export CI_BRANCH=$DRONE_BRANCH

# Check Kernel Version
KERVER=$(make kernelversion)

# Set a commit head
COMMIT_HEAD=$(git log --oneline -1)

# Set Date
DATE=$(TZ=Asia/Jakarta date +"%Y%m%d-%T")

##-----------------------------------------------------##

clone() {
	echo " "
	msg "|| Cloning Clang ||"
	git clone --depth=1 https://github.com/kdrag0n/proton-clang clang-llvm --no-tags --single-branch

		# Toolchain Directory defaults to clang-llvm
	TC_DIR=$KERNEL_DIR/clang-llvm

	msg "|| Cloning Anykernel ||"
	git clone --depth 1 --no-single-branch https://github.com/Reinazhard/AnyKernel3.git -b master
}

##------------------------------------------------------##

exports() {
	export ARCH=arm64
	export SUBARCH=arm64
	export token=$TELEGRAM_TOKEN

	KBUILD_COMPILER_STRING=$("$TC_DIR"/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
	PATH=$TC_DIR/bin/:$PATH

	export PATH KBUILD_COMPILER_STRING
	export BOT_MSG_URL="https://api.telegram.org/bot$token/sendMessage"
	export BOT_BUILD_URL="https://api.telegram.org/bot$token/sendDocument"
	PROCS=$(($(nproc --all) + 2))
	export PROCS
}

##---------------------------------------------------------##

tg_post_msg() {
	curl -s -X POST "$BOT_MSG_URL" -d chat_id="$2" \
	-d "disable_web_page_preview=true" \
	-d "parse_mode=html" \
	-d text="$1"

}

##----------------------------------------------------------------##

tg_post_build() {
	curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
	-F chat_id="$2"  \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=html" \
	-F caption="$3 | <code>Build Number : </code><b>$DRONE_BUILD_NUMBER</b>"
}

##----------------------------------------------------------##

build_kernel() {

    tg_post_msg "<b>🔨 $KBUILD_BUILD_VERSION CI Build Triggered</b>%0A<b>Kernel Version : </b><code>$KERVER</code>%0A<b>Date : </b><code>$(TZ=Asia/Jakarta date)</code>%0A<b>Compiler Used : </b><code>$KBUILD_COMPILER_STRING</code>%0a<b>Branch : </b><code>$CI_BRANCH</code>%0A<b>HEAD : </b><a href='$DRONE_COMMIT_LINK'>$COMMIT_HEAD</a>" "$CHATID"
    make O=out $DEFCONFIG LLVM=1 LLVM_IAS=1 CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_COMPAT=arm-linux-gnueabi-

	msg "|| Started Compilation ||"
	BUILD_START=$(date +"%s")
	make -j"$PROCS" O=out LLVM=1 LLVM_IAS=1 CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
	BUILD_END=$(date +"%s")
	DIFF=$((BUILD_END - BUILD_START))

		if [ -f "$KERNEL_DIR"/out/arch/arm64/boot/Image.gz-dtb ]
	    then
	    	msg "|| Kernel successfully compiled ||"
			gen_zip
		else
				tg_post_msg "<b>❌ Build failed to compile after $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds</b>" "$CHATID"
		fi

}

##--------------------------------------------------------------##

gen_zip() {
	msg "|| Zipping into a flashable zip ||"
	cp "$KERNEL_DIR"/out/arch/arm64/boot/Image.gz-dtb AnyKernel3/Image.gz-dtb
	cd AnyKernel3 || exit
	zip -r9 $ZIPNAME-$DEVICE-"$DRONE_BUILD_NUMBER" * -x .git README.md

	## Prepare a final zip variable
	ZIP_FINAL="$ZIPNAME-$DEVICE-$DRONE_BUILD_NUMBER.zip"
	tg_post_build "$ZIP_FINAL" "$CHATID" "✅ Build took : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"
	cd ..
	rm -rf AnyKernel3
}

clone
exports
build_kernel

##----------------*****-----------------------------##
