terraform {
  backend "s3" {
    bucket = "000630-jeff"
    key    = "vpc/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

provider "aws" {
  region = "ap-northeast-2"
}


# VPC 리소스 생성
variable "vpc_main_cidr" {
  description = "VPC main CIDR block"
  default     = "192.168.0.0/24"
}

# VPC 생성
resource "aws_vpc" "my_vpc" {
  cidr_block           = var.vpc_main_cidr
  instance_tenancy     = "default"
  enable_dns_hostnames = false

  tags = {
    Name = "Jeff-VPC-1"
  }
}

# AZ-a 서브넷
resource "aws_subnet" "pub_sub_A" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.my_vpc.cidr_block, 3, 0)
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "Jeff-Public-Subnet-A"
  }
}

resource "aws_subnet" "nat_sub_1_A" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.my_vpc.cidr_block, 3, 1)
  availability_zone = "ap-northeast-2a"

  tags = {
    Name = "Jeff-NAT-Subnet-1-A"
  }
}

resource "aws_subnet" "nat_sub_2_A" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.my_vpc.cidr_block, 3, 2)
  availability_zone = "ap-northeast-2a"

  tags = {
    Name = "Jeff-NAT-Subnet-2-A"
  }
}

resource "aws_subnet" "prv_sub_A" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.my_vpc.cidr_block, 3, 3)
  availability_zone = "ap-northeast-2a"

  tags = {
    Name = "Jeff-Private-Subnet-A"
  }
}

# AZ-c 서브넷
resource "aws_subnet" "pub_sub_C" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.my_vpc.cidr_block, 3, 4)
  availability_zone       = "ap-northeast-2c"
  map_public_ip_on_launch = true

  tags = {
    Name = "Jeff-Public-Subnet-C"
  }
}

resource "aws_subnet" "nat_sub_1_C" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.my_vpc.cidr_block, 3, 5)
  availability_zone = "ap-northeast-2c"

  tags = {
    Name = "Jeff-NAT-Subnet-1-C"
  }
}

resource "aws_subnet" "nat_sub_2_C" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.my_vpc.cidr_block, 3, 6)
  availability_zone = "ap-northeast-2c"

  tags = {
    Name = "Jeff-NAT-Subnet-2-C"
  }
}

resource "aws_subnet" "prv_sub_C" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.my_vpc.cidr_block, 3, 7)
  availability_zone = "ap-northeast-2c"

  tags = {
    Name = "Jeff-Private-Subnet-C"
  }
}




# 인터넷 게이트웨이 생성
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "Jeff-IGW"
  }
}

# NAT Gateway EIP 생성
resource "aws_eip" "nat_eip1" {
  domain = "vpc"
}

resource "aws_eip" "nat_eip2" {
  domain = "vpc"
}

# NAT Gateway 생성
resource "aws_nat_gateway" "nat_gw_A" {
  allocation_id = aws_eip.nat_eip1.id
  subnet_id     = aws_subnet.pub_sub_A.id

  depends_on = [aws_internet_gateway.my_igw]

  tags = {
    Name = "Jeff-NAT-GW-A"
  }
}

resource "aws_nat_gateway" "nat_gw_C" {
  allocation_id = aws_eip.nat_eip2.id
  subnet_id     = aws_subnet.pub_sub_C.id

  depends_on = [aws_internet_gateway.my_igw]

  tags = {
    Name = "Jeff-NAT-GW-C"
  }
}

# 퍼블릭 라우트 테이블 생성
resource "aws_route_table" "pub_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "Jeff-RT-PUB"
  }
}

# NAT 라우트 테이블 (프라이빗 서브넷에서 NAT Gateway로 트래픽 전달)
resource "aws_route_table" "nat_rt_A" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw_A.id
  }

  tags = {
    Name = "Jeff-RT-NAT-A"
  }
}

resource "aws_route_table" "nat_rt_C" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw_C.id
  }

  tags = {
    Name = "Jeff-RT-NAT-C"
  }
}

# 프라이빗 서브넷의 내부 라우트 테이블 생성
resource "aws_route_table" "prv_rt" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "Jeff-RT-PRV"
  }
}

# 퍼블릭 서브넷에 퍼블릭 라우트 테이블 연결
resource "aws_route_table_association" "pub_rt_asso1" {
  subnet_id      = aws_subnet.pub_sub_A.id
  route_table_id = aws_route_table.pub_rt.id
}

resource "aws_route_table_association" "pub_rt_asso2" {
  subnet_id      = aws_subnet.pub_sub_C.id
  route_table_id = aws_route_table.pub_rt.id
}

# NAT 서브넷과 NAT 라우트 테이블 연결
resource "aws_route_table_association" "nat_rt_A_asso1" {
  subnet_id      = aws_subnet.nat_sub_1_A.id
  route_table_id = aws_route_table.nat_rt_A.id
}

resource "aws_route_table_association" "nat_rt_A_asso2" {
  subnet_id      = aws_subnet.nat_sub_2_A.id
  route_table_id = aws_route_table.nat_rt_A.id
}

resource "aws_route_table_association" "nat_rt_C_asso1" {
  subnet_id      = aws_subnet.nat_sub_1_C.id
  route_table_id = aws_route_table.nat_rt_C.id
}

resource "aws_route_table_association" "nat_rt_C_asso2" {
  subnet_id      = aws_subnet.nat_sub_2_C.id
  route_table_id = aws_route_table.nat_rt_C.id
}

# 프라이빗 서브넷과 프라이빗 라우트 테이블 연결
resource "aws_route_table_association" "prv_rt_asso1" {
  subnet_id      = aws_subnet.prv_sub_A.id
  route_table_id = aws_route_table.prv_rt.id
}

resource "aws_route_table_association" "prv_rt_asso2" {
  subnet_id      = aws_subnet.prv_sub_C.id
  route_table_id = aws_route_table.prv_rt.id
}


