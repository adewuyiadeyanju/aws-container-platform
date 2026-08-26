resource "aws_db_subnet_group" "main" {
  name = "${local.name_prefix}-rds"

  subnet_ids = [
    aws_subnet.private[0].id,
    aws_subnet.private[1].id,
  ]

  tags = {
    Name = "${local.name_prefix}-rds"
  }
}

resource "aws_db_instance" "main" {
  identifier = "${local.name_prefix}-postgres"

  engine         = "postgres"
  engine_version = "17"

  instance_class        = "db.t4g.micro"
  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "fieldops"
  username = "fieldops"

  manage_master_user_password = true

  port = 5432

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible = false

  multi_az = false

  backup_retention_period = 1
  backup_window           = "03:00-04:00"

  maintenance_window = "sun:04:00-sun:05:00"

  auto_minor_version_upgrade = true

  deletion_protection = false
  skip_final_snapshot = true

  copy_tags_to_snapshot = true

  tags = {
    Name = "${local.name_prefix}-postgres"
  }
}