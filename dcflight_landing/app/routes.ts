import { type RouteConfig, index, route } from "@react-router/dev/routes";

export default [
  index("routes/home.tsx"),
  route("/docs", "routes/docs.tsx"),
  route("/roadmap", "routes/roadmap.tsx"),
] satisfies RouteConfig;
