import 'reflect-metadata';
import { DataSource } from 'typeorm';
import * as path from 'path';

const nodeEnv = process.env.NODE_ENV || 'development';
const isProduction = nodeEnv === 'production';
const isDevelopment = nodeEnv === 'development';

// Hard-disable synchronize outside development. In dev it may be enabled via env.
const synchronize = isDevelopment
  ? process.env.DB_SYNCHRONIZE === 'true'
  : false;

// Startup assertion: never allow synchronize in production.
if (isProduction && synchronize) {
  // eslint-disable-next-line no-console
  console.error(
    '[ormconfig] FATAL: TypeORM synchronize must be false in production. Refusing to start.',
  );
  process.exit(1);
}

export const AppDataSource = new DataSource({
  type: 'postgres',
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  username: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || process.env.DB_PASS || '',
  database: process.env.DB_NAME || 'dupdub',
  entities: [path.join(__dirname, 'src/**/*.entity{.ts,.js}')],
  migrations: [path.join(__dirname, 'src/database/migrations/*{.ts,.js}')],
  migrationsTableName: 'typeorm_migrations',
  synchronize,
  extra: {
    max: parseInt(process.env.DB_POOL_MAX || '10', 10),
    min: parseInt(process.env.DB_POOL_MIN || '2', 10),
    connectionTimeoutMillis: parseInt(process.env.DB_ACQUIRE_TIMEOUT_MS || '10000', 10),
    idleTimeoutMillis: parseInt(process.env.DB_IDLE_TIMEOUT_MS || '60000', 10),
  },
});

export default AppDataSource;
