import { Construct } from 'constructs';
import { App, Chart, ChartProps, Size } from 'cdk8s';
import * as kplus from 'cdk8s-plus-27';

export class MyChart extends Chart {
  constructor(scope: Construct, id: string, props: ChartProps = {}) {
    super(scope, id, props);

    const deployment = new kplus.Deployment(this, 'Deployment', {
      metadata: {
        name: 'cdk8s-test-app',
      },
      replicas: 4,
      containers: [{
        name: 'test-app',
        image: 'nginx:latest',
        portNumber: 80,
        resources: {
          cpu: { request: kplus.Cpu.millis(200), limit: kplus.Cpu.millis(1000) },
          memory: { request: Size.mebibytes(256), limit: Size.gibibytes(1) }
        }
      }]
    });

    deployment.exposeViaService({
      name: 'cdk8s-test-app',
      ports: [{ port: 80, targetPort: 80 }]
    });
  }
}

const app = new App();
new MyChart(app, 'cdk8s-test-app', { labels: { app: 'cdk8s-test-app' } });
app.synth();
