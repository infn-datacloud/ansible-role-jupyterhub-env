.PHONY: all deps lint syntax test

all: deps lint test

deps:
	python -m pip install -U pip
	python -m pip install "ansible-core>=2.18" ansible-lint yamllint
	ansible-galaxy collection install -r requirements.yml
	printf '[defaults]\nroles_path=../\n' > ansible.cfg

lint: deps
	yamllint .
	ansible-lint

syntax: deps
	ansible-playbook tests/test.yml -i tests/inventory --syntax-check

test: syntax
	ansible-playbook tests/test.yml -i tests/inventory
