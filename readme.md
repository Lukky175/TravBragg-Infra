Current:- 
  This is The Readme File For TravBragg.

<!-- To see which port ArgoCD is Using:- (30080) -->
kubectl get svc argocd-server -n argocd  

<!-- To be fmt friendly (Pipeline stage) (Terraform Format)-->
terraform fmt -recursive

<!-- To Check Logs of userdata Script -->
sudo cat /var/log/user-data-debug.log

<!-- % To Get argo cd password -->
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

<!-- To Check Grafana Username & Password -->
kubectl get secret monitoring-grafana -n monitoring \
-o jsonpath="{.data.admin-user}" | base64 -d ; echo

kubectl get secret monitoring-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 -d ; echo







<!-- Pipeline checks format -->
terraform fmt -check (Checks Format)

pipeline is enforcing terraform fmt -check -recursive

logs /var/log/cloud-init-output.log (In EC-2)

$ sudo cat /var/log/user-data-debug.log to see logs