'use strict';

module.directive('focus', [
  'pageService', function (page) {
    var link = function ($scope, $element, $attrs) {
      if ($attrs.focus === '' || $scope.$eval($attrs.focus)) {
        page.$timeout(function () {
          $element.focus();
        }, 0);
      }
    };

    return {
      restrict: 'A',
      link: link,
    };
  }
]);
