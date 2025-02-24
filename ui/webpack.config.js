import path from 'path';
import HtmlWebpackPlugin from 'html-webpack-plugin';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export default {
  entry: './src/main.tsx',
  output: {
    path: path.resolve(__dirname, 'dist'),
    filename: '[name].[contenthash].js',
    clean: true
  },
  module: {
    rules: [
      {
        test: /\.(ts|tsx)$/,
        exclude: /node_modules/,
        use: 'ts-loader',
      },
      {
        test: /\.css$/,
        use: ['style-loader', 'css-loader', 'postcss-loader'],
      }
    ]
  },
  resolve: {
    extensions: ['.tsx', '.ts', '.js'],
  },
  plugins: [
    new HtmlWebpackPlugin({
      template: './index.html'
    })
  ],
  devServer: {
    static: {
      directory: path.join(__dirname, 'public'),
    },
    proxy: [
      {
        context: '/api',
        target: 'http://localhost:3000',
        secure: false,
        changeOrigin: true,
        logLevel: 'debug',
      },
    ],
    hot: true,
    compress: true,
    port: 5173,
    historyApiFallback: true,
  }
}