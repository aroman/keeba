# (C) 2013 Avi Romanoff <avi at romanoff dot me> 

REPORTER = spec

serve: build
	@node server.js

docs: clean-docs
	@./node_modules/docco/bin/docco *.coffee

clean-docs:
	@rm -rf docs

test:
	@./node_modules/mocha/bin/mocha \
	 --compilers coffee:coffee-script \
	 --reporter $(REPORTER)

build:
	@coffee --compile *.coffee
	@handlebars views/templates --min --output static/js/templates.min.js

clean:
	@rm *.js

deploy-staging: build test
	@git push staging jbha-config:master
	@heroku config:set GIT_REV=`git rev-parse --short HEAD` --app keeba-staging

deploy-production: build test
	@git push production jbha-config:master
	@heroku config:set GIT_REV=`git rev-parse --short HEAD` --app keeba

.PHONY: build clean serve test docs clean-docs
