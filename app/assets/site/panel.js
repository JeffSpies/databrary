'use strict';

app.directive('panel', [
  'constantService',
  function (constants) {
    var link = function ($scope, $element, $attrs, ctrl, transclude) {
      if (angular.isDefined($attrs.id)) {
        $scope.id = $attrs.id;
        $element.addClass($attrs.id);
      } else {
        $scope.id = '';
      }

      $scope.title = constants.message($attrs.panelTitle);
      $scope.top = 'top' in $attrs;
      $scope.enabled = true;
      $scope.edit = $attrs.editLink;
      //

      $scope.getPanelClasses = function () {
        var classes = {};

        classes.panel = true;
        classes[$scope.id] = true;

        return classes;
      };

      //

      transclude($scope, function ($clone) {
        $element.find('[panel-body]').append($clone);
      });

      if ($scope.refreshPanel)
        $scope.refreshPanel();
    };

    return {
      restrict: 'E',
      scope: true,
      templateUrl: 'site/panel.html',
      transclude: true,
      replace: true,
      priority: 100,
      link: link
    };
  }
]);
