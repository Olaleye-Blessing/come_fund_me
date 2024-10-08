import express from 'express';
import morgan from 'morgan';
import cors from 'cors';
import cookieParser from 'cookie-parser';
import { envVars } from './utils/env-data';
import { globalErrorHanlder } from './utils/errors/global-err-handler';
import { imgsUpload } from './utils/multer';
import { uploadImage } from './campaign/controller';

const app = express();

if (envVars.NODE_ENV !== 'production') app.use(morgan('dev'));

const allowedOrigins = envVars.ALLOWED_ORIGINS.split(',').map((origin) => {
  if (!origin.startsWith('/')) return origin;

  return new RegExp(origin.slice(1, -1));
});

app.use(cors({ origin: allowedOrigins, credentials: true }));

app.use(cookieParser());

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.post('/api/v1/image', imgsUpload.single('image'), uploadImage);

app.use(globalErrorHanlder);

export default app;
