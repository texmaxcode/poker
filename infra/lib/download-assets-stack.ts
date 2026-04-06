import * as cdk from "aws-cdk-lib";
import * as cloudfront from "aws-cdk-lib/aws-cloudfront";
import * as origins from "aws-cdk-lib/aws-cloudfront-origins";
import * as s3 from "aws-cdk-lib/aws-s3";
import type { Construct } from "constructs";

/**
 * Private S3 bucket + CloudFront (OAC) for Windows/macOS installers.
 * Upload builds to s3://{bucket}/downloads/ via CI or aws s3 cp.
 */
export class DownloadAssetsStack extends cdk.Stack {
  public readonly bucket: s3.Bucket;
  public readonly distribution: cloudfront.Distribution;

  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    this.bucket = new s3.Bucket(this, "InstallerBucket", {
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      encryption: s3.BucketEncryption.S3_MANAGED,
      enforceSSL: true,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      autoDeleteObjects: false,
    });

    this.distribution = new cloudfront.Distribution(this, "InstallerDistribution", {
      comment: "Texas Hold'em Gym — installer downloads (S3 origin)",
      defaultRootObject: undefined,
      priceClass: cloudfront.PriceClass.PRICE_CLASS_100,
      defaultBehavior: {
        origin: origins.S3BucketOrigin.withOriginAccessControl(this.bucket),
        viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
        allowedMethods: cloudfront.AllowedMethods.ALLOW_GET_HEAD_OPTIONS,
        cachedMethods: cloudfront.CachedMethods.CACHE_GET_HEAD_OPTIONS,
        compress: true,
      },
    });

    const baseUrl = `https://${this.distribution.distributionDomainName}`;

    new cdk.CfnOutput(this, "InstallerBucketName", {
      value: this.bucket.bucketName,
      description: "Upload installers to s3://{bucket}/downloads/",
    });

    new cdk.CfnOutput(this, "CloudFrontDomain", {
      value: this.distribution.distributionDomainName,
    });

    new cdk.CfnOutput(this, "NextPublicDownloadBaseUrl", {
      value: baseUrl,
      description: "Set NEXT_PUBLIC_DOWNLOAD_BASE_URL in Amplify (no trailing slash)",
    });

    new cdk.CfnOutput(this, "UploadExample", {
      value: `aws s3 cp TexasHoldemGym-Windows-x64.zip s3://${this.bucket.bucketName}/downloads/texas-holdem-gym-windows.exe`,
      description: "Example — adjust artifact name to match website/src/lib/downloads.ts",
    });
  }
}
