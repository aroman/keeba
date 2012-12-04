REPORTER = list

serve: build
	@export GIT_REV=`git rev-parse --short HEAD`
	@node server.js

docs: clean-docs
	@./node_modules/docco/bin/docco *.coffee

clean-docs:
	@rm -rf docs

test:
	@./node_modules/mocha/bin/mocha --timeout 15000 \
	 --compilers coffee:coffee-script \
	 --reporter $(REPORTER)

build:
	@coffee --compile *.coffee
	@handlebars views/templates --min --output static/js/templates.min.js

clean:
	@rm *.js

deploy-staging: build test
	@git push staging
	@heroku config:set GIT_REV=`git rev-parse --short HEAD` --app keeba-staging

.PHONY: build clean serve test docs clean-docs