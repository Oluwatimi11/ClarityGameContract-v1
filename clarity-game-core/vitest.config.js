/// <reference types="vitest" />

import { defineConfig } from "vitest/config";
import path from "path";
import { vitestSetupFilePath, getClarinetVitestsArgv } from "@hirosystems/clarinet-sdk/vitest";

export default defineConfig({
  test: {
    environment: "clarinet",
    pool: "forks",
    poolOptions: {
      threads: { singleThread: true },
      forks: { singleFork: true },
    },
    setupFiles: [
      path.resolve(vitestSetupFilePath),
    ],
    environmentOptions: {
      clarinet: {
        network: 'simnet',
      },
    }
  },
});
