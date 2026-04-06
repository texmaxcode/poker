#!/usr/bin/env node
import "source-map-support/register";
import * as cdk from "aws-cdk-lib";
import { DownloadAssetsStack } from "../lib/download-assets-stack";
import { AmplifyHostingStack } from "../lib/amplify-hosting-stack";

const app = new cdk.App();

const env: cdk.Environment = {
  account: process.env.CDK_DEFAULT_ACCOUNT,
  region: process.env.CDK_DEFAULT_REGION ?? "us-east-1",
};

new DownloadAssetsStack(app, "TexasHoldemGym-DownloadAssets", {
  env,
  description: "S3 + CloudFront for Windows/macOS installer downloads",
});

const githubOwner = app.node.tryGetContext("githubOwner") as string | undefined;
const githubRepo = app.node.tryGetContext("githubRepo") as string | undefined;
const githubToken = app.node.tryGetContext("githubToken") as string | undefined;

if (githubOwner && githubRepo && githubToken) {
  new AmplifyHostingStack(app, "TexasHoldemGym-AmplifyHosting", {
    env,
    githubOwner,
    githubRepo,
    githubToken,
    description: "Amplify Hosting for Next.js site",
    productionBranch: (app.node.tryGetContext("productionBranch") as string) ?? "main",
  });
}

app.synth();
