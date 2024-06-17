ifeq (.private,$(wildcard .private))
PRIVATE = 1
endif

bootstrap: bootstrap-client bootstrap-server

homebrew: homebrew-client homebrew-server

test: test-client build-client-preview-apps test-server

clean: clean-client clean-server

# client

bootstrap-client: check-dependencies-client audio fonts words-import words-import-sqlite secrets

check-dependencies-client:
ifdef PRIVATE
	@$(MAKE) homebrew-client
else
	@echo "  ⚠️  Checking for Git LFS..."
	@command -v git-lfs >/dev/null || (echo "$$GITLFS_ERROR_INSTALL" && exit 1)
	@command -v git config --get-regexp filter.lfs >/dev/null 2>&1 \
		|| (echo "$$GITLFS_ERROR_INSTALL_2" && exit 1)
	@echo "  ✅ Git LFS is good to go!"
	@git lfs pull
endif

PLATFORM_IOS = iOS Simulator,id=$(call udid_for,iOS 17.4,iPhone \d\+ Pro [^M])
test-client:
	@xcodebuild test \
		-project App/isowords.xcodeproj \
		-scheme isowords \
		-destination platform="$(PLATFORM_IOS)" \
		-skipMacroValidation

build-client-preview-apps:
	@xcodebuild \
    -project App/isowords.xcodeproj \
    -list \
    -skipMacroValidation
	@xcodebuild \
		-project App/isowords.xcodeproj \
		-scheme CubeCorePreview \
		-destination platform="$(PLATFORM_IOS)" \
    -skipMacroValidation
	@xcodebuild \
		-project App/isowords.xcodeproj \
		-scheme CubePreviewPreview \
		-destination platform="$(PLATFORM_IOS)" \
    -skipMacroValidation
	@xcodebuild \
		-project App/isowords.xcodeproj \
		-scheme GameOverPreview \
		-destination platform="$(PLATFORM_IOS)" \
    -skipMacroValidation
	@xcodebuild \
		-project App/isowords.xcodeproj \
		-scheme HomeFeaturePreview \
		-destination platform="$(PLATFORM_IOS)" \
    -skipMacroValidation
	@xcodebuild \
		-project App/isowords.xcodeproj \
		-scheme LeaderboardsPreview \
		-destination platform="$(PLATFORM_IOS)" \
    -skipMacroValidation
	@xcodebuild \
		-project App/isowords.xcodeproj \
		-scheme OnboardingPreview \
		-destination platform="$(PLATFORM_IOS)" \
    -skipMacroValidation
	@xcodebuild \
		-project App/isowords.xcodeproj \
		-scheme SettingsPreview \
		-destination platform="$(PLATFORM_IOS)" \
    -skipMacroValidation
	@xcodebuild \
		-project App/isowords.xcodeproj \
		-scheme UpgradeInterstitialPreview \
		-destination platform="$(PLATFORM_IOS)" \
    -skipMacroValidation

clean-client: clean-audio

homebrew-client: homebrew-shared
	@brew ls ffmpeg --versions || brew install ffmpeg

audio: audio-clean audio-touch audio-download audio-sounds audio-music

audio-clean:
	@rm -rf Assets/Audio/
	@rm -f Sources/AppAudioLibrary/Resources/*
	@rm -f Sources/AppClipAudioLibrary/Resources/*
	@mkdir -p Sources/AppAudioLibrary/Resources/
	@mkdir -p Sources/AppClipAudioLibrary/Resources/

AUDIO_URL = $(shell heroku config:get AUDIO_URL -a isowords-staging)
audio-download:
ifdef PRIVATE
	@curl -o Audio.zip $(AUDIO_URL)
	@unzip Audio.zip -d Assets/
	@rm Audio.zip
endif

audio-touch:
	@touch Sources/AppAudioLibrary/Resources/empty.mp3
	@touch Sources/AppClipAudioLibrary/Resources/empty.mp3

audio-sounds:
ifdef PRIVATE
	@for file in Assets/Audio/Sounds/App/*.wav; \
		do \
		filename=`basename $$file .wav`; \
		echo Converting $$filename...; \
		ffmpeg -y -v 0 -i $$file -vn -ar 44100 -ac 2 -b:a 64k Sources/AppAudioLibrary/Resources/$${filename}.mp3; \
		done
	@for file in Assets/Audio/Sounds/Core/*.wav; \
		do \
		filename=`basename $$file .wav`; \
		echo Converting $$filename...; \
		ffmpeg -y -v 0 -i $$file -vn -ar 44100 -ac 2 -b:a 32k Sources/AppClipAudioLibrary/Resources/$${filename}.mp3; \
		done
endif

audio-music:
ifdef PRIVATE
	@for file in Assets/Audio/Music/App/*.wav; \
		do \
		filename=`basename $$file .wav`; \
		echo Converting $$filename...; \
		ffmpeg -y -v 0 -i $$file -vn -ar 44100 -ac 2 -b:a 64k Sources/AppAudioLibrary/Resources/$${filename}.mp3; \
		done
	@for file in Assets/Audio/Music/Core/*.wav; \
		do \
		filename=`basename $$file .wav`; \
		echo Converting $$filename...; \
		ffmpeg -y -v 0 -i $$file -vn -ar 44100 -ac 2 -b:a 32k Sources/AppClipAudioLibrary/Resources/$${filename}.mp3; \
		done
endif

clean-audio:
	@rm -f Sources/AppAudioLibrary/Resources/*.wav
	@rm -f Sources/AppClipAudioLibrary/Resources/*.wav
	@mkdir -p Sources/AppAudioLibrary/Resources/
	@mkdir -p Sources/AppClipAudioLibrary/Resources/

FONTS_URL = $(shell heroku config:get FONTS_URL -a isowords-staging)
fonts:
ifdef PRIVATE
	@rm -f Sources/Styleguide/Fonts/*
	@curl -o fonts.zip $(FONTS_URL)
	@unzip fonts.zip -d Sources/Styleguide/Fonts/
	@rm -f fonts.zip
else
	@touch Sources/Styleguide/Fonts/empty.otf
endif

DICTIONARY_URL = $(shell heroku config:get DICTIONARY_URL -a isowords-staging)
DICTIONARY_GZIP = Sources/DictionaryFileClient/Dictionaries/Words.en.txt.gz
words-import:
	@rm -f $(DICTIONARY_GZIP)
ifdef PRIVATE
	@curl -o $(DICTIONARY_GZIP) $(DICTIONARY_URL)
else
	@echo -e "CUBES\nREMOVES" \
		| cat - /usr/share/dict/words \
		| tr a-z A-Z \
		| sort -u \
		| grep '^[A-Z]\{3,\}$$' \
		| gzip > $(DICTIONARY_GZIP)
endif

DICTIONARY_DB = Sources/DictionarySqliteClient/Dictionaries/Words.en.db
words-import-sqlite: words-import
	@rm -f $(DICTIONARY_DB)
	@gunzip --stdout $(DICTIONARY_GZIP) \
		| sqlite3 \
		--init Bootstrap/sqlite-words-import.sql \
		$(DICTIONARY_DB)

secrets:
ifdef PRIVATE
	@echo "// This is generated by \`make secrets\`. Don't edit.\nlet secrets = \"$$(heroku config:get SECRETS -a isowords-staging)\"" > Sources/ApiClientLive/Secrets.swift
else
	@cp Sources/ApiClientLive/Secrets.swift.example Sources/ApiClientLive/Secrets.swift
endif

# server

bootstrap-server: check-dependencies-server

check-dependencies-server:
ifdef PRIVATE
	@$(MAKE) homebrew-server
else
	@echo "  ⚠️  Checking on PostgreSQL..."
	@command -v psql >/dev/null || (echo "$$POSTGRES_ERROR_INSTALL" && exit 1)
	@psql template1 --command '' 2>/dev/null || \
		(echo "$$POSTGRES_ERROR_RUNNING" && exit 1)
	@echo "  ✅ PostgreSQL is up and running!"
	@psql --dbname=isowords_development --username=isowords --command '' \
		2>/dev/null || (echo "$$POSTGRES_WARNING" && $(MAKE) --quiet db)
endif

test-server:
	@TEST_SERVER=1 swift test

run-server-linux:
	@docker-compose \
		--file Bootstrap/development-compose.yml \
		--project-directory . \
		up \
		--build

test-server-linux:
	docker run --rm -v "$(PWD):$(PWD)" -w "$(PWD)" swift:5.9.2-focal bash Bootstrap/test.sh

clean-server: clean-db

homebrew-server: homebrew-shared
	@brew ls postgresql@12 --versions || brew install postgresql@12
	@if test "$(PRIVATE)" != ""; then \
		brew tap heroku/brew; \
		brew ls heroku --versions || brew install heroku; \
		fi

db:
	@createuser --superuser isowords || true
	@psql template1 -c "ALTER USER isowords PASSWORD 'isowords';"
	@createdb --owner isowords isowords_development || true
	@createdb --owner isowords isowords_test || true

clean-db:
	@dropdb --username isowords isowords_development || true
	@dropdb --username isowords isowords_test || true
	@dropuser isowords || true

env-example:
	@cp Bootstrap/iso-env-example .iso-env

# shared

homebrew-shared:
	@brew ls git-lfs --versions || brew install git-lfs

# private

private: .private

.private:
	touch .private

HEROKU_NAME = isowords-staging
HEROKU_VERSION = $(shell heroku releases -a isowords -n 1 | tail -1 | sed -n -e 's/\(v[0-9]*\).*/\1/p')
deploy-server: check-porcelain
	@git fetch origin
	@test "$$(git status --porcelain)" = "" \
		|| (echo "  🛑 Can't deploy while the working tree is dirty" && exit 1)
	@test "$$(git rev-parse @)" = "$$(git rev-parse origin/main)" \
		&& test "$$(git rev-parse --abbrev-ref HEAD)" = "main" \
		|| (echo "  🛑 Must deploy from an up-to-date origin/main" && exit 1)
	@heroku container:login
	@cd Bootstrap && heroku container:push web --context-path .. -a $(HEROKU_NAME)
	@heroku container:release web -a $(HEROKU_NAME)
	@git tag -a "$(HEROKU_NAME)-deploy-$(HEROKU_VERSION)" -m "Deploy"
	@git push origin main
	@git push origin "$(HEROKU_NAME)-deploy-$(HEROKU_VERSION)"

archive-marketing: check-porcelain set-marketing-version archive

archive: bootstrap-client
	 @$(MAKE) bump-build
	 @cd App \
	   && xcodebuild -project isowords.xcodeproj -scheme "isowords" -skipMacroValidation archive \
		 || (git checkout . && echo "  🛑 Failed to build archive" && exit 1)
	 @git add . && git commit -m "Bumped version to $$(cd App && agvtool what-version -terse)"
	 @git tag -a "archive-$$(cd App && agvtool what-version -terse)" -m "Archive"
	 @git tag -a "$$(cd App && agvtool what-marketing-version -terse1)" -f -m "Marketing Version"
	 @git push origin main
	 @git push origin "archive-$$(cd App && agvtool what-version -terse)"
	 @git push origin "$$(cd App && agvtool what-marketing-version -terse1)"

archive-debug: bootstrap-client
	 @cd App \
	   && xcodebuild -project isowords.xcodeproj -scheme "isowords" -configuration Debug -archivePath $(ARCHIVE_PATH) -skipMacroValidation archive \
		 || (git checkout . && echo "  🛑 Failed to build archive" && exit 1)

set-marketing-version:
	@cd App && agvtool new-marketing-version $(VERSION)

bump-build:
	@cd App && xcrun agvtool next-version -all

check-porcelain:
	@test "$(PRIVATE)" != "" || exit 1
	@git fetch origin
	@test "$$(git status --porcelain)" = "" \
		|| (echo "  🛑 Can't proceed while the working tree is dirty" && exit 1)
	@test "$$(git rev-parse @)" = "$$(git rev-parse origin/main)" \
		&& test "$$(git rev-parse --abbrev-ref HEAD)" = "main" \
		|| (echo "  🛑 Can only proceed from an up-to-date origin/main" && exit 1)

app-preview-iphone:
	ffmpeg -i $(MP4) -acodec copy -crf 12 -vf scale=886:1920,setsar=1:1,fps=30 iphone.mp4

app-preview-ipad:
	ffmpeg -i $(MP4) -acodec copy -crf 12 -vf crop=1200:1600,setsar=1:1,fps=30 ipad.mp4

env-staging:
	@heroku config --json -a isowords-staging > .iso-env

ngrok:
	@ngrok http -hostname=pointfreeco-localhost.ngrok.io 9876

format:
	@swift format \
		--ignore-unparsable-files \
		--in-place \
		--recursive \
		./App/ \
		./Package.swift \
		./Sources/

loc:
	find . -name '*.swift' | xargs wc -l | sort -nr

export GITLFS_ERROR_INSTALL
define GITLFS_ERROR_INSTALL
  🛑 Git LFS is not installed! isowords stores its assets in Git LFS.

     Install it with your favorite package manager, e.g.:

       $$ \033[1mbrew\033[0m \033[38;5;66minstall git-lfs\033[0m

     And run the following command before proceeding:

       $$ \033[1mgit\033[0m \033[38;5;66mlfs install\033[0m

endef

export GITLFS_ERROR_INSTALL_2
define GITLFS_ERROR_INSTALL_2
  🛑 Git LFS is not configured! isowords cannot fetch its assets.

     Run the following command before proceeding:

       $$ \033[1mgit\033[0m \033[38;5;66mlfs install\033[0m

endef

define POSTGRES_ERROR_INSTALL
  🛑 PostgreSQL not found! The isowords backend depends on this.

     Install it with your favorite package manager, e.g.:

       $$ \033[1mbrew\033[0m \033[38;5;66minstall postgresql\033[0m

endef
export POSTGRES_ERROR_INSTALL

define POSTGRES_ERROR_RUNNING
  🛑 PostgreSQL isn't running! The isowords backend depends on this.

     Make sure it's spawned by running, e.g., if installed via Homebrew:

       $$ \033[1mbrew\033[0m \033[38;5;66mservices start postgresql@15\033[0m

endef
export POSTGRES_ERROR_RUNNING

define POSTGRES_WARNING
  ⚠️  Local databases aren't configured! Creating isowords user/databases...

     Reset at any time with:

       $$ \033[1mmake\033[0m \033[38;5;66mclean-db\033[0m

endef
export POSTGRES_WARNING

define udid_for
$(shell xcrun simctl list devices available '$(1)' | grep '$(2)' | sort -r | head -1 | awk -F '[()]' '{ print $$(NF-3) }')
endef
