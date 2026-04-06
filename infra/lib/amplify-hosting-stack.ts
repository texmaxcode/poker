import * as cdk from "aws-cdk-lib";
import * as amplify from "aws-cdk-lib/aws-amplify";
import * as iam from "aws-cdk-lib/aws-iam";
import type { Construct } from "constructs";

export interface AmplifyHostingStackProps extends cdk.StackProps {
  /** GitHub org or user */
  githubOwner: string;
  /** Repository name (without org) */
  githubRepo: string;
  /** GitHub personal access token with repo scope */
  githubToken: string;
  /** Branch that receives production traffic */
  productionBranch: string;
}

/**
 * Amplify Hosting (Next.js SSR / WEB_COMPUTE) wired to a GitHub repository.
 * Build settings come from the repo root `amplify.yml` (monorepo appRoot).
 */
export class AmplifyHostingStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: AmplifyHostingStackProps) {
    super(scope, id, props);

    const repoUrl = `https://github.com/${props.githubOwner}/${props.githubRepo}`;

    const amplifyServiceRole = new iam.Role(this, "AmplifyServiceRole", {
      assumedBy: new iam.ServicePrincipal("amplify.amazonaws.com"),
      description: "Amplify Hosting build & SSR for Texas Hold'em Gym website",
    });

    amplifyServiceRole.addManagedPolicy(
      iam.ManagedPolicy.fromAwsManagedPolicyName("AdministratorAccess-Amplify"),
    );

    const app = new amplify.CfnApp(this, "WebApp", {
      name: "texas-holdem-gym-web",
      description: "Texas Hold'em Gym marketing site (Next.js)",
      repository: repoUrl,
      oauthToken: props.githubToken,
      platform: "WEB_COMPUTE",
      iamServiceRole: amplifyServiceRole.roleArn,
    });

    new amplify.CfnBranch(this, "ProductionBranch", {
      appId: app.attrAppId,
      branchName: props.productionBranch,
      stage: "PRODUCTION",
      enableAutoBuild: true,
    });

    new cdk.CfnOutput(this, "AmplifyAppId", {
      value: app.attrAppId,
      description: "Amplify console: open app by ID in AWS console",
    });

    new cdk.CfnOutput(this, "AmplifyAppDefaultDomain", {
      value: app.attrDefaultDomain,
      description: "Amplify default domain (branch subdomain is shown in AWS console)",
    });
  }
}
