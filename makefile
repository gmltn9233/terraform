# Terraform 실행 순서 지정
DIRS := \
	backend \
	vpc \
	openvpn \
	front/alb \
	front/cluster \
	back/alb \
	back/cluster \
	github-actions-role \
	ecr \
	codedeploy \
	rds \
	cloudfront \

.PHONY: init plan apply

init:
	@for dir in $(DIRS); do \
		echo "\n🔧 Running terraform init in $$dir"; \
		cd $$dir && terraform init && cd - > /dev/null; \
	done

plan:
	@for dir in $(DIRS); do \
		echo "\n🔍 Running terraform plan in $$dir"; \
		cd $$dir && terraform plan && cd - > /dev/null; \
	done

apply:
	@for dir in $(DIRS); do \
		echo "\n🚀 Running terraform apply in $$dir"; \
		cd $$dir && terraform apply -auto-approve && cd - > /dev/null; \
	done

# 파괴할 때는 의존성 반대로 실행
REVERSE_DIRS := \
	cloudfront \
	rds \
	codedeploy \
	ecr \
	github-actions-role \
	back/cluster \
	back/alb \
	front/cluster \
	front/alb \
	openvpn \
	vpc \
	backend

destroy:
	@for dir in $(REVERSE_DIRS); do \
		echo "\n💥 Destroying Terraform resources in $$dir"; \
		cd $$dir && terraform destroy -auto-approve && cd - > /dev/null; \
	done